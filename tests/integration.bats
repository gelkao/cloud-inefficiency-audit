#!/usr/bin/env bats
# Success-path integration test. It performs real downloads, so it is OPT-IN:
# provide your customer number and a saved invoice page via the environment.
# Without them the credential-dependent tests skip (no network in CI).
#
#   HETZNER_CN=K... INVOICE_HTML=data/your-invoices.html bats tests/integration.bats
#
# The real-data audit smoke test audits every customer dataset placed under
# ./data (one subfolder of CSVs each). It runs locally only — on CI ./data is
# empty, so it skips.
#
# Asserts are generic — shapes and counts only, never specific months/amounts.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DATA_DIR="$(mktemp -d)"
}

teardown() {
  [[ -n "${DATA_DIR:-}" && -d "$DATA_DIR" ]] && rm -rf "$DATA_DIR"
}

need_creds() {
  [[ -n "${HETZNER_CN:-}"   ]] || skip "set HETZNER_CN to run the success path"
  [[ -n "${INVOICE_HTML:-}" ]] || skip "set INVOICE_HTML to a saved invoice page"
  [[ -f "${INVOICE_HTML}"   ]] || skip "INVOICE_HTML not found: ${INVOICE_HTML}"
}

datasets() {  # each data/<name>/ folder that holds invoice CSVs
  shopt -s nullglob
  local d csvs
  for d in "$ROOT"/data/*/; do
    csvs=( "$d"*.csv )
    [ "${#csvs[@]}" -ge 1 ] && printf '%s\n' "${d%/}"
  done
}

@test "update_prices fetches well-formed price and spec tables from the live endpoint" {
  [[ -z "${GITHUB_ACTIONS:-}" ]] || skip "live price pull runs locally only, not in CI"
  LIVE_PRICES_URL="https://gelkao.com/live"
  source "$ROOT/lib.sh"
  live="$BATS_TEST_TMPDIR/live"
  run update_prices "$LIVE_PRICES_URL" "$live"
  [ "$status" -eq 0 ]
  [ -s "$live/hetzner/prices.csv" ]
  [ -s "$live/hetzner/server_types.csv" ]
  head -1 "$live/hetzner/prices.csv"       | grep -q '^type,price_group,currency'
  head -1 "$live/hetzner/server_types.csv" | grep -q '^type,vcpu,ram_gb'
}

@test "gelkao list yields at least one well-formed UUID" {
  need_creds
  run bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' list"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 1 ]
  for line in "${lines[@]}"; do
    [[ "$line" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
  done
}

@test "pipeline downloads CSVs named <CN>-YYYY-MM-<uuid>.csv and prints a summary" {
  need_creds
  run bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' list | '$ROOT/gelkao' -d '$DATA_DIR' fetch '$HETZNER_CN'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Done\.\ downloaded=[0-9]+\ skipped=[0-9]+\ failed=[0-9]+ ]]
  shopt -s nullglob
  files=( "$DATA_DIR/${HETZNER_CN}"-[0-9][0-9][0-9][0-9]-[0-9][0-9]-*.csv )
  [ "${#files[@]}" -ge 1 ]
  [ -s "${files[0]}" ]
}

@test "re-running the pipeline skips already-downloaded invoices" {
  need_creds
  bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' list | '$ROOT/gelkao' -d '$DATA_DIR' fetch '$HETZNER_CN'"
  run bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' list | '$ROOT/gelkao' -d '$DATA_DIR' fetch '$HETZNER_CN'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ downloaded=0 ]]
}

@test "gelkao fetch errors without a customer number (no creds needed)" {
  # Unset HETZNER_CN so the suite's own env can't satisfy the requirement.
  run env -u HETZNER_CN bash -c "echo 00000000-0000-0000-0000-000000000000 | '$ROOT/gelkao' fetch"
  [ "$status" -ne 0 ]
}

@test "smoke: audit every real dataset under data/ and report each savings figure" {
  [[ -z "${GITHUB_ACTIONS:-}" ]] || skip "real-data smoke test runs locally only, not in CI"
  local d name out n=0
  while read -r d; do
    name=$(basename "$d")
    out=$("$ROOT/gelkao" -q -d "$d" -f "$BATS_TEST_TMPDIR/$name.db" audit) \
      || { echo "audit failed for $name"; return 1; }
    grep -qE 'price group +: [a-z]+'        <<<"$out" || { echo "no price group for $name"; return 1; }
    grep -qE 'would save : [0-9]+\.[0-9]+%'  <<<"$out" || { echo "no savings figure for $name"; return 1; }
    echo "  $name — $(grep -oE 'would save : [0-9]+\.[0-9]+%' <<<"$out")" >&3
    n=$((n+1))
  done < <(datasets)
  [ "$n" -ge 1 ] || { echo "no datasets under $ROOT/data/*/ (each needs a K file + CSVs)"; return 1; }
}

@test "audit runs the committed synthetic examples with no credentials or network" {
  run "$ROOT/gelkao" -q -d "$ROOT/examples" -f "$BATS_TEST_TMPDIR/example.db" audit
  [ "$status" -eq 0 ]
  [[ "$output" =~ price\ group\ +:\ eu ]]
  [[ "$output" =~ would\ save\ :\ 3[0-9]\.[0-9]+% ]]
  [ -f "$BATS_TEST_TMPDIR/example.db" ]
  [ ! -f "$ROOT/examples/gelkao.db" ]
}

@test "gelkao <cn> end-to-end downloads then reports a positive line count" {
  need_creds
  run bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' -d '$DATA_DIR' '$HETZNER_CN'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Done\.\ downloaded=[0-9]+ ]]           # fetch stage ran
  [[ "$output" =~ would\ save\ :\ [0-9]+\.[0-9]+% ]]        # audit stage ran
}
