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

@test "gelkao -d <dir> fetch looks in <dir> (skips a pre-seeded invoice, no network)" {
  d="$BATS_TEST_TMPDIR/f"; mkdir -p "$d"
  uuid=11111111-2222-3333-4444-555555555555
  invoice_csv "$d/K0000000000-2025-11-$uuid.csv"
  run bash -c "echo '$uuid' | '$ROOT/gelkao' -d '$d' fetch K0000000000"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]]
}

@test "gelkao -d is rejected for list" {
  run "$ROOT/gelkao" -d /tmp list
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid for list"* ]]
}

@test "gelkao -f is rejected for list and fetch" {
  run "$ROOT/gelkao" -f /tmp/x.db list
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid for list"* ]]

  run "$ROOT/gelkao" -f /tmp/x.db fetch K0000000000
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
  a="$BATS_TEST_TMPDIR/assets3"; fixture_assets "$a"; rm "$a/providers/hetzner/prices.csv"
  d="$BATS_TEST_TMPDIR/inv3"; mkdir -p "$d"; cx33_invoice "$d/i.csv"
  run build_db "$BATS_TEST_TMPDIR/f3.db" "$a" "$d"
  [ "$status" -ne 0 ]
  [[ "$output" == *"prices.csv"* ]]
}

@test "build_db uses a live/ price override instead of the committed providers/ table" {
  a="$BATS_TEST_TMPDIR/assetsL"; fixture_assets "$a"
  mkdir -p "$a/live/hetzner"
  cat > "$a/live/hetzner/prices.csv" <<CSV
type,price_group,currency,effective_from,price_hourly,price_monthly
cx33,eu,eur,2025-10-01,0.0080,4.99
cax21,eu,eur,2025-10-01,0.0070,3.50
CSV
  cp "$a/providers/hetzner/server_types.csv" "$a/live/hetzner/server_types.csv"
  d="$BATS_TEST_TMPDIR/invL"; mkdir -p "$d"; cx33_invoice "$d/i.csv"
  db="$BATS_TEST_TMPDIR/fL.db"
  run build_db "$db" "$a" "$d"
  [ "$status" -eq 0 ]
  [ "$(sqlite3 "$db" "SELECT printf('%.2f', optimal) FROM priced;")" = "3.50" ]
}

@test "an untouched box across the 15-Jun hike is scored month by month: its optimal rises 6.49 (Jun) to 8.49 (Jul) as the cheap alternative recedes" {
  a="$BATS_TEST_TMPDIR/uha"; jun2026_assets "$a"
  d="$BATS_TEST_TMPDIR/uhd"; mkdir -p "$d"; jun2026_untouched_invoice "$d/i.csv"
  db="$BATS_TEST_TMPDIR/uh.db"; build_db "$db" "$a" "$d" >/dev/null
  [ "$(sqlite3 "$db" "SELECT printf('%.2f', optimal) FROM priced WHERE month='2026-06';")" = "6.49" ]
  [ "$(sqlite3 "$db" "SELECT printf('%.2f', optimal) FROM priced WHERE month='2026-07';")" = "8.49" ]
}

@test "a lone post-15-Jun invoice still detects its price group from an old locked rate, so the box is priced against the cheaper type (no false 0%)" {
  a="$BATS_TEST_TMPDIR/pha"; jun2026_assets "$a"
  d="$BATS_TEST_TMPDIR/phd"; mkdir -p "$d"; jun2026_post_hike_only_invoice "$d/i.csv"
  db="$BATS_TEST_TMPDIR/ph.db"; build_db "$db" "$a" "$d" >/dev/null
  [ "$(sqlite3 "$db" "SELECT price_group FROM detected_group;")" = "eu" ]
  [ "$(sqlite3 "$db" "SELECT printf('%.2f', optimal) FROM priced;")" = "8.49" ]
}

@test "a same-type box reacquired after the hike is optimal at the new price, not judged against the torn-down box's gone April rate" {
  a="$BATS_TEST_TMPDIR/ra"; jun2026_solo_assets "$a"
  d="$BATS_TEST_TMPDIR/rd"; mkdir -p "$d"; jun2026_reacquired_invoice "$d/i.csv"
  db="$BATS_TEST_TMPDIR/r.db"; build_db "$db" "$a" "$d" >/dev/null
  [ "$(sqlite3 "$db" "SELECT printf('%.2f', optimal) FROM priced WHERE box='t2';")" = "22.08" ]
}

@test "gelkao -d <dir> <cn> runs the whole pipeline into <dir>: extract, fetch (skip), audit" {
  d="$BATS_TEST_TMPDIR/g"; mkdir -p "$d"
  uuid=11111111-2222-3333-4444-555555555555
  invoice_csv "$d/K0000000000-2025-11-$uuid.csv"   # pre-seeded -> fetch skips, no network
  html="$BATS_TEST_TMPDIR/page.html"
  printf '<a href="https://usage.hetzner.com/%s">x</a>\n' "$uuid" > "$html"

  run bash -c "cat '$html' | '$ROOT/gelkao' -d '$d' K0000000000"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]]                     # fetch skipped the pre-seeded invoice in <dir> (no curl)
  [[ "$output" == *"would save"* ]]               # audit ran end-to-end
  [ -f "$d/gelkao.db" ]
}

@test "gelkao -q audit is accepted and produces an audit" {
  d="$BATS_TEST_TMPDIR/q"; mkdir -p "$d"
  invoice_csv "$d/K0000000000-2025-11-x.csv"
  run bash -c "'$ROOT/gelkao' -q -d '$d' audit"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would save"* ]]
}

@test "require_sqlite rejects sqlite older than 3.32" {
  stub="$BATS_TEST_TMPDIR/old"; mkdir -p "$stub"
  printf '#!/bin/sh\necho "3.7.17 2013-05-20 00:48:51"\n' > "$stub/sqlite3"
  chmod +x "$stub/sqlite3"
  PATH="$stub:$PATH" run require_sqlite
  [ "$status" -ne 0 ]
  [[ "$output" == *"too old"* ]]
}

@test "require_sqlite accepts sqlite 3.32 or newer" {
  stub="$BATS_TEST_TMPDIR/new"; mkdir -p "$stub"
  printf '#!/bin/sh\necho "3.40.1 2022-12-28 14:03:47"\n' > "$stub/sqlite3"
  chmod +x "$stub/sqlite3"
  PATH="$stub:$PATH" run require_sqlite
  [ "$status" -eq 0 ]
}

@test "require_sqlite fails when sqlite3 is not installed" {
  PATH="$BATS_TEST_TMPDIR" run require_sqlite
  [ "$status" -ne 0 ]
  [[ "$output" == *"install sqlite3"* ]]
}

@test "require_curl fails when curl is not installed" {
  PATH="$BATS_TEST_TMPDIR" run require_curl
  [ "$status" -ne 0 ]
  [[ "$output" == *"install curl"* ]]
}

@test "resolve_asset prefers a live/ copy over the committed providers/ file, else falls back" {
  repo="$BATS_TEST_TMPDIR/repo"; mkdir -p "$repo/providers/hetzner" "$repo/live/hetzner"
  : > "$repo/providers/hetzner/prices.csv"
  : > "$repo/providers/hetzner/server_types.csv"

  run resolve_asset hetzner/server_types.csv "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "$repo/providers/hetzner/server_types.csv" ]

  : > "$repo/live/hetzner/prices.csv"
  run resolve_asset hetzner/prices.csv "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "$repo/live/hetzner/prices.csv" ]
}

@test "update_prices fails and leaves no override when the server has no file" {
  repo="$BATS_TEST_TMPDIR/repoF"; mkdir -p "$repo/providers/hetzner"
  : > "$repo/providers/hetzner/prices.csv"; : > "$repo/providers/hetzner/server_types.csv"

  curl() { return 22; }

  run update_prices https://gelkao.com "$repo/live"
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed to fetch"* ]]
  [ ! -f "$repo/live/hetzner/prices.csv" ]

  run resolve_asset hetzner/prices.csv "$repo"
  [ "$output" = "$repo/providers/hetzner/prices.csv" ]
}

@test "update_prices downloads both tables into live/hetzner and resolve_asset then prefers them" {
  repo="$BATS_TEST_TMPDIR/repoS"; mkdir -p "$repo/providers/hetzner"
  : > "$repo/providers/hetzner/prices.csv"; : > "$repo/providers/hetzner/server_types.csv"

  curl() {
    local f=""
    while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { f="$2"; shift; }; shift; done
    printf 'fresh\n' > "$f"
    return 0
  }

  run update_prices https://gelkao.com "$repo/live"
  [ "$status" -eq 0 ]
  [ -s "$repo/live/hetzner/prices.csv" ]
  [ -s "$repo/live/hetzner/server_types.csv" ]

  run resolve_asset hetzner/prices.csv "$repo"
  [ "$output" = "$repo/live/hetzner/prices.csv" ]
}

@test "maybe_refresh_prices is a no-op (no prompt, no fetch) when not interactive" {
  update_prices() { touch "$BATS_TEST_TMPDIR/fetched"; }

  run maybe_refresh_prices https://gelkao.com "$BATS_TEST_TMPDIR/live"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/fetched" ]
}
