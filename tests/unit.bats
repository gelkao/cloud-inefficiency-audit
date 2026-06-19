#!/usr/bin/env bats
# Unit tests for lib.sh — pure logic, no network, no credentials.
# Run: bats tests/unit.bats

setup() {
  # shellcheck source=../lib.sh
  source "$BATS_TEST_DIRNAME/../lib.sh"
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

invoice_csv() {  # <file> — one invoice data row (content irrelevant; Stage 0 only counts rows)
  cat > "$1" <<CSV
grouping,product,description,reference,quantity,from,until,condition,unit,external id,price,total
"Project test","CX32 Cloud Server",,,"1.0000",2025-11-01,2025-11-30,,"Months","box1",,"€ 6.3000"
CSV
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

@test "analyze builds the db and reports the loaded line count" {
  d="$BATS_TEST_TMPDIR/a"; mkdir -p "$d"; invoice_csv "$d/a.csv"; invoice_csv "$d/b.csv"
  run analyze "$ROOT" "$d" "$BATS_TEST_TMPDIR/a.db"
  [ "$status" -eq 0 ]
  [ "$output" = "invoice lines loaded: 2" ]   # 2 files x 1 data row, header skipped
}

@test "build_db fails when the data dir has no CSVs" {
  d="$BATS_TEST_TMPDIR/empty"; mkdir -p "$d"
  run build_db "$BATS_TEST_TMPDIR/e.db" "$ROOT" "$d"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no invoice CSVs"* ]]
}
