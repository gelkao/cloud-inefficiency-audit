#!/usr/bin/env bats

setup() {
  # shellcheck source=../lib.sh
  source "$BATS_TEST_DIRNAME/../lib.sh"
  load fixtures
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

cx33_db() {
  local a="$BATS_TEST_TMPDIR/a" d="$BATS_TEST_TMPDIR/d"
  fixture_assets "$a"
  mkdir -p "$d"; cx33_invoice "$d/i.csv"
  build_db "$BATS_TEST_TMPDIR/r.db" "$a" "$d" >/dev/null
  printf '%s' "$BATS_TEST_TMPDIR/r.db"
}

rounding_db() {
  local a="$BATS_TEST_TMPDIR/ra" d="$BATS_TEST_TMPDIR/rd"
  rounding_assets "$a"
  mkdir -p "$d"; rounding_invoice "$d/i.csv"
  build_db "$BATS_TEST_TMPDIR/rr.db" "$a" "$d" >/dev/null
  printf '%s' "$BATS_TEST_TMPDIR/rr.db"
}

locked_pair_db() {
  local a="$BATS_TEST_TMPDIR/lpa" d="$BATS_TEST_TMPDIR/lpd"
  jun2026_assets "$a" 2026-06-15
  mkdir -p "$d"; jun2026_locked_pair_invoice "$d/i.csv"
  build_db "$BATS_TEST_TMPDIR/lp.db" "$a" "$d" >/dev/null
  printf '%s' "$BATS_TEST_TMPDIR/lp.db"
}

@test "stat_period spans the first and last invoice month" {
  db=$(cx33_db)
  run stat_period "$db"
  [ "$output" = "2025-11 .. 2025-11  (1 months)" ]
}

@test "stat_currency reads the invoice currency" {
  db=$(cx33_db)
  run stat_currency "$db"
  [ "$output" = "EUR" ]
}

@test "stat_servers counts distinct boxes" {
  db=$(cx33_db)
  run stat_servers "$db"
  [ "$output" = "1" ]
}

@test "account_price_group reports the detected group" {
  db=$(cx33_db)
  run account_price_group "$db"
  [ "$output" = "eu" ]
}

@test "stat_total_paid sums the paid column" {
  db=$(cx33_db)
  run stat_total_paid "$db"
  [ "$output" = "4.99" ]
}

@test "stat_run_rate is the last month's spend" {
  db=$(cx33_db)
  run stat_run_rate "$db"
  [ "$output" = "4.99" ]
}

@test "stat_savings_pct rounds the savings percentage" {
  db=$(rounding_db)
  run stat_savings_pct "$db"
  [ "$output" = "38.8" ]
}

@test "stat_savings_amount rounds the paid-optimal gap" {
  db=$(rounding_db)
  run stat_savings_amount "$db"
  [ "$output" = "4" ]
}

@test "stat_recoverable_pct is the paid-vs-prevailing-list gap" {
  db=$(locked_pair_db)
  run stat_recoverable_pct "$db"
  [ "$output" = "0.0" ]
}

@test "stat_recoverable_amount rounds the paid-vs-prevailing-list gap" {
  db=$(locked_pair_db)
  run stat_recoverable_amount "$db"
  [ "$output" = "0" ]
}

@test "stat_lost_pct is the ceiling-minus-recoverable gap" {
  db=$(locked_pair_db)
  run stat_lost_pct "$db"
  [ "$output" = "13.4" ]
}

@test "stat_lost_amount rounds the ceiling-minus-recoverable gap" {
  db=$(locked_pair_db)
  run stat_lost_amount "$db"
  [ "$output" = "2" ]
}

@test "stat_servers scopes to one project via the grouping filter" {
  a="$BATS_TEST_TMPDIR/a2"; fixture_assets "$a"
  d="$BATS_TEST_TMPDIR/d2"; mkdir -p "$d"; two_project_invoice "$d/i.csv"
  db="$BATS_TEST_TMPDIR/r2.db"; build_db "$db" "$a" "$d" >/dev/null

  run stat_servers "$db"
  [ "$output" = "2" ]
  run stat_servers "$db" "WHERE grouping = 'Project prod'"
  [ "$output" = "1" ]
}

@test "savings_color picks red at or above 50%" {
  run savings_color 50 RED AMBER GREEN
  [ "$output" = "RED" ]
  run savings_color 73 RED AMBER GREEN
  [ "$output" = "RED" ]
}

@test "savings_color picks amber from 20% up to 49%" {
  run savings_color 20 RED AMBER GREEN
  [ "$output" = "AMBER" ]
  run savings_color 49 RED AMBER GREEN
  [ "$output" = "AMBER" ]
}

@test "savings_color picks green below 20%" {
  run savings_color 19 RED AMBER GREEN
  [ "$output" = "GREEN" ]
  run savings_color 0 RED AMBER GREEN
  [ "$output" = "GREEN" ]
}

@test "audit assembles the header lines and the monthly table" {
  a="$BATS_TEST_TMPDIR/a3"; fixture_assets "$a"
  d="$BATS_TEST_TMPDIR/d3"; mkdir -p "$d"; cx33_invoice "$d/i.csv"
  run audit "$a" "$d" "$BATS_TEST_TMPDIR/r3.db"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "period            : 2025-11 .. 2025-11  (1 months)" ]
  [ "${lines[1]}" = "currency          : EUR  (detected from invoices)" ]
  [ "${lines[2]}" = "servers analysed  : 1" ]
  [ "${lines[3]}" = "price group       : eu" ]
  [ "${lines[4]}" = "total paid        : €4.99" ]
  [ "${lines[5]}" = "current run-rate  : €4.99/mo (last invoice)" ]
  [ "${lines[7]}" = "picking the cheapest same-spec type each month would save : 24.0%  (€1)" ]
  [[ "${lines[10]}" =~ ^2025-11[[:space:]]+paid[[:space:]]+5[[:space:]]+optimal[[:space:]]+4[[:space:]]+#+[[:space:]]+24%$ ]]
}

@test "audit -g scopes the whole report to one project" {
  a="$BATS_TEST_TMPDIR/a4"; fixture_assets "$a"
  d="$BATS_TEST_TMPDIR/d4"; mkdir -p "$d"; two_project_invoice "$d/i.csv"
  run audit "$a" "$d" "$BATS_TEST_TMPDIR/r4.db" "Project prod"
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "servers analysed  : 1" ]
  [ "${lines[3]}" = "price group       : eu" ]
  [[ "${lines[10]}" =~ ^2025-11[[:space:]]+paid[[:space:]]+5[[:space:]]+optimal[[:space:]]+4[[:space:]]+#+[[:space:]]+24%$ ]]
}

@test "the monthly table percent is rounded" {
  a="$BATS_TEST_TMPDIR/ra2"; rounding_assets "$a"
  d="$BATS_TEST_TMPDIR/rd2"; mkdir -p "$d"; rounding_invoice "$d/i.csv"
  run audit "$a" "$d" "$BATS_TEST_TMPDIR/rr2.db"
  [ "$status" -eq 0 ]
  [[ "${lines[10]}" =~ [[:space:]]39%$ ]]
}

@test "the saving splits into still-recoverable and already-lost lines" {
  a="$BATS_TEST_TMPDIR/lps"; jun2026_assets "$a" 2026-06-15
  d="$BATS_TEST_TMPDIR/lpsd"; mkdir -p "$d"; jun2026_locked_pair_invoice "$d/i.csv"
  run audit "$a" "$d" "$BATS_TEST_TMPDIR/lps.db"
  [ "$status" -eq 0 ]
  [[ "$output" =~ recoverable.*0\.0%.*\(€0\) ]]
  [[ "$output" =~ lost.*13\.4%.*\(€2\) ]]
}
