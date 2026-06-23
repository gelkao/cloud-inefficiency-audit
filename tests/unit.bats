#!/usr/bin/env bats

setup() {
  # shellcheck source=../lib.sh
  source "$BATS_TEST_DIRNAME/../lib.sh"
  load fixtures
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "invoice_csv_url builds the CSV download URL with cn" {
  run invoice_csv_url 00000000-0000-0000-0000-000000000000 K0000000000
  [ "$status" -eq 0 ]
  [ "$output" = "https://usage.hetzner.com/00000000-0000-0000-0000-000000000000?csv&cn=K0000000000" ]
}

@test "month_of_csv extracts YYYY-MM from the first ISO date" {
  f="$BATS_TEST_TMPDIR/a.csv"
  printf 'grouping,from,total\nServer,2025-03-14,1.00\n' > "$f"
  run month_of_csv "$f"
  [ "$status" -eq 0 ]
  [ "$output" = "2025-03" ]
}

@test "month_of_csv is empty when there is no date" {
  f="$BATS_TEST_TMPDIR/b.csv"
  printf 'no dates in here\n' > "$f"
  run month_of_csv "$f"
  [ "$output" = "" ]
}

@test "extract_uuids pulls UUIDs out of invoice HTML" {
  f="$BATS_TEST_TMPDIR/page.html"
  cat > "$f" <<'HTML'
<a href="https://usage.hetzner.com/11111111-2222-3333-4444-555555555555">detail</a>
<a href="https://usage.hetzner.com/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee?csv">csv</a>
<a href="/invoice/089000837082/pdf">old format, ignored</a>
HTML
  run extract_uuids "$f"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

# curl is stubbed as a tripwire: any invocation drops a marker file. The skip
# path must never reach it.
@test "fetch_one skips an already-present invoice WITHOUT touching the network" {
  out="$BATS_TEST_TMPDIR/out"; mkdir -p "$out"
  uuid=11111111-2222-3333-4444-555555555555
  : > "$out/K0000000000-2025-03-$uuid.csv"   # pretend it was downloaded earlier

  curl() { touch "$BATS_TEST_TMPDIR/curl_called"; return 1; }

  run fetch_one "$uuid" K0000000000 "$out"
  [ "$status" -eq 10 ]
  [[ "$output" == skip* ]]
  [ ! -e "$BATS_TEST_TMPDIR/curl_called" ]   # network was never touched
}

# Stub curl to emulate a successful download (-o <file>), and confirm the file
# is named <cn>-<YYYY-MM>-<uuid>.csv.
@test "fetch_one downloads and names the file <cn>-<YYYY-MM>-<uuid>.csv" {
  out="$BATS_TEST_TMPDIR/out2"; mkdir -p "$out"
  uuid=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee

  curl() {
    local f=""
    while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { f="$2"; shift; }; shift; done
    printf 'grouping,from,total\nServer,2024-12-05,1.00\n' > "$f"
    return 0
  }

  run fetch_one "$uuid" K0000000000 "$out"
  [ "$status" -eq 0 ]
  [[ "$output" == ok* ]]
  [ -f "$out/K0000000000-2024-12-$uuid.csv" ]
}

@test "gelkao -g is rejected for list and fetch" {
  run "$ROOT/gelkao" -g "Project prod" list
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid for list"* ]]

  run "$ROOT/gelkao" -g "Project prod" fetch K0000000000
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid for fetch"* ]]
}

@test "build_db fails when the data dir has no CSVs" {
  d="$BATS_TEST_TMPDIR/empty"; mkdir -p "$d"
  run build_db "$BATS_TEST_TMPDIR/e.db" "$ROOT" "$d"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no invoice CSVs"* ]]
}

@test "build_db loads the tables, detects the group, and prices the cheaper same-spec type" {
  a="$BATS_TEST_TMPDIR/assets"; fixture_assets "$a"
  d="$BATS_TEST_TMPDIR/inv"; mkdir -p "$d"; cx33_invoice "$d/i.csv"
  db="$BATS_TEST_TMPDIR/f.db"
  run build_db "$db" "$a" "$d"
  [ "$status" -eq 0 ]
  [ "$(sqlite3 "$db" 'SELECT count(*) FROM prices;')" -eq 3 ]
  [ "$(sqlite3 "$db" 'SELECT count(*) FROM server_types;')" -eq 2 ]
  [ "$(sqlite3 "$db" 'SELECT price_group FROM detected_group;')" = "eu" ]
  [ "$(sqlite3 "$db" "SELECT printf('%.2f|%.2f', paid, optimal) FROM priced;")" = "4.99|3.79" ]
}

@test "build_db fails when a price asset is missing" {
  a="$BATS_TEST_TMPDIR/assets3"; fixture_assets "$a"; rm "$a/hetzner_prices.csv"
  d="$BATS_TEST_TMPDIR/inv3"; mkdir -p "$d"; cx33_invoice "$d/i.csv"
  run build_db "$BATS_TEST_TMPDIR/f3.db" "$a" "$d"
  [ "$status" -ne 0 ]
  [[ "$output" == *"hetzner_prices.csv"* ]]
}

@test "gelkao <cn> runs the whole pipeline: extract, fetch (skip), audit" {
  d="$BATS_TEST_TMPDIR/g"; mkdir -p "$d"
  uuid=11111111-2222-3333-4444-555555555555
  invoice_csv "$d/K0000000000-2025-11-$uuid.csv"   # pre-seeded -> fetch skips, no network
  html="$BATS_TEST_TMPDIR/page.html"
  printf '<a href="https://usage.hetzner.com/%s">x</a>\n' "$uuid" > "$html"

  run bash -c "cat '$html' | DATA_DIR='$d' '$ROOT/gelkao' K0000000000"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]]                     # fetch skipped the pre-seeded invoice (no curl)
  [[ "$output" == *"would save"* ]]               # audit ran end-to-end
}
