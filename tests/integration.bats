#!/usr/bin/env bats
# Success-path integration test. It performs real downloads, so it is OPT-IN:
# provide your customer number and a saved invoice page via the environment.
# Without them the credential-dependent tests skip (no network in CI).
#
#   HETZNER_CN=K... INVOICE_HTML=data/your-invoices.html bats tests/integration.bats
#
# Asserts are generic — shapes and counts only, never specific months/amounts.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DATA_DIR="$(mktemp -d)"
  export DATA_DIR
}

teardown() {
  [[ -n "${DATA_DIR:-}" && -d "$DATA_DIR" ]] && rm -rf "$DATA_DIR"
}

need_creds() {
  [[ -n "${HETZNER_CN:-}"   ]] || skip "set HETZNER_CN to run the success path"
  [[ -n "${INVOICE_HTML:-}" ]] || skip "set INVOICE_HTML to a saved invoice page"
  [[ -f "${INVOICE_HTML}"   ]] || skip "INVOICE_HTML not found: ${INVOICE_HTML}"
}

need_data() {  # audit needs only local CSVs — no network, no credentials
  shopt -s nullglob
  local csvs=( "$ROOT"/data/*.csv )
  [ "${#csvs[@]}" -ge 1 ] || skip "no CSVs in data/ — run the fetch pipeline first"
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
  run bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' list | '$ROOT/gelkao' fetch '$HETZNER_CN'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Done\.\ downloaded=[0-9]+\ skipped=[0-9]+\ failed=[0-9]+ ]]
  shopt -s nullglob
  files=( "$DATA_DIR/${HETZNER_CN}"-[0-9][0-9][0-9][0-9]-[0-9][0-9]-*.csv )
  [ "${#files[@]}" -ge 1 ]
  [ -s "${files[0]}" ]
}

@test "re-running the pipeline skips already-downloaded invoices" {
  need_creds
  bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' list | '$ROOT/gelkao' fetch '$HETZNER_CN'"
  run bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' list | '$ROOT/gelkao' fetch '$HETZNER_CN'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ downloaded=0 ]]
}

@test "gelkao fetch errors without a customer number (no creds needed)" {
  # Unset HETZNER_CN so the suite's own env can't satisfy the requirement.
  run env -u HETZNER_CN bash -c "echo 00000000-0000-0000-0000-000000000000 | '$ROOT/gelkao' fetch"
  [ "$status" -ne 0 ]
}

@test "audit loads the real invoice CSVs in data/ and reports a savings figure" {
  need_data
  DATA_DIR="$ROOT/data" DB="$BATS_TEST_TMPDIR/audit.db" run "$ROOT/gelkao" audit
  [ "$status" -eq 0 ]
  [[ "$output" =~ price\ group:\ [a-z]+ ]]
  [[ "$output" =~ would\ save\ [0-9]+\.[0-9]+% ]]
}

@test "gelkao <cn> end-to-end downloads then reports a positive line count" {
  need_creds
  run bash -c "cat '$INVOICE_HTML' | '$ROOT/gelkao' '$HETZNER_CN'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Done\.\ downloaded=[0-9]+ ]]           # fetch stage ran
  [[ "$output" =~ would\ save\ [0-9]+\.[0-9]+% ]]        # audit stage ran
}
