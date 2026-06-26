#!/usr/bin/env bash

UUID_RE='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

die() { echo "error: $*" >&2; exit 1; }

require_sqlite() {
  command -v sqlite3 >/dev/null 2>&1 || die "sqlite3 not found — install sqlite3 (3.32+ required)"
  local ver maj min
  ver=$(sqlite3 --version | cut -d' ' -f1)
  IFS=. read -r maj min _ <<<"$ver"
  if (( maj < 3 || (maj == 3 && min < 32) )); then
    die "sqlite3 $ver is too old — need 3.32+ for '.import --skip 1'"
  fi
}

require_curl() {
  command -v curl >/dev/null 2>&1 || die "curl not found — install curl to download invoices"
}

info() {
  local fd=$1 msg=$2 g='' r=''
  [ -t "$fd" ] && { g=$'\e[90m'; r=$'\e[0m'; }
  if [ "$fd" = 2 ]; then printf '%s%s%s\n' "$g" "$msg" "$r" >&2
  else printf '%s%s%s\n' "$g" "$msg" "$r"; fi
}

extract_uuids() {
  grep -ohiE "usage\.hetzner\.com/${UUID_RE}" "$@" | sed 's|.*/||'
}

list_invoices() {
  local uuids
  uuids=$(extract_uuids "$@" || true)
  if [[ -z "$uuids" ]]; then
    echo "warning: no UUIDs found — has Hetzner changed the invoice URL?" >&2
    return 1
  fi
  printf '%s\n' "$uuids"
}

invoice_csv_url() { printf 'https://usage.hetzner.com/%s?csv&cn=%s' "$1" "$2"; }

month_of_csv() {
  local d
  d=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$1" | head -1 || true)
  printf '%s' "${d:0:7}"
}


fetch_one() {
  local uuid=$1 cn=$2 data_dir=$3 staging month out
  local existing=( "$data_dir/${cn}"-*-"${uuid}.csv" )

  if [[ -e "${existing[0]}" ]]; then
    info 1 "skip"$'\t'"${existing[0]}"
    return 10
  fi

  require_curl
  staging="$data_dir/.${uuid}.part"
  if ! curl -sSfL -o "$staging" "$(invoice_csv_url "$uuid" "$cn")"; then
    rm -f "$staging"
    printf 'fail\t%s\n' "$uuid" >&2
    return 1
  fi

  month=$(month_of_csv "$staging")
  if [[ -z "$month" ]]; then
    rm -f "$staging"
    printf 'fail\t%s\tno-dates\n' "$uuid" >&2
    return 1
  fi

  out="$data_dir/${cn}-${month}-${uuid}.csv"
  mv "$staging" "$out"
  info 1 "ok"$'\t'"$out"
  return 0
}

fetch_all() {
  local cn=$1 data_dir=${2:-data} uuid rc ok=0 skip=0 fail=0
  mkdir -p "$data_dir"
  while read -r uuid; do
    [[ -n "${uuid:-}" ]] || continue
    rc=0
    fetch_one "$uuid" "$cn" "$data_dir" || rc=$?
    case $rc in
      0)  ok=$((ok+1)) ;;
      10) skip=$((skip+1)) ;;
      *)  fail=$((fail+1)) ;;
    esac
  done
  info 2 "Done. downloaded=$ok skipped=$skip failed=$fail"
}

import_invoices() {
  local db=$1 data_dir=$2 f found=0
  for f in "$data_dir"/*.csv; do
    [ -e "$f" ] || continue
    sqlite3 "$db" ".mode csv" ".import --skip 1 '$f' raw_invoices" 2>/dev/null
    found=1
  done
  [ "$found" = 1 ] || die "no invoice CSVs in $data_dir/"
}

build_db() {
  local db=$1 assets=$2 data_dir=$3
  require_sqlite
  [ -f "$assets/hetzner_prices.csv" ] || die "missing hetzner_prices.csv in $assets"
  [ -f "$assets/server_types.csv" ]   || die "missing server_types.csv in $assets"
  rm -f "$db"
  sqlite3 "$db" < "$assets/schema.sql"
  import_invoices "$db" "$data_dir"
  sqlite3 "$db" ".mode csv" ".import --skip 1 '$assets/hetzner_prices.csv' prices"
  sqlite3 "$db" ".mode csv" ".import --skip 1 '$assets/server_types.csv' server_types"
  sqlite3 "$db" < "$assets/audit.sql"
}

grouping_filter() {
  [ -n "${1:-}" ] || return 0
  printf "WHERE grouping = '%s'" "${1//\'/\'\'}"
}

stat_period()         { sqlite3 "$1" "SELECT printf('%s .. %s  (%d months)', MIN(month), MAX(month), COUNT(DISTINCT month)) FROM priced ${2:-};"; }
stat_currency()       { sqlite3 "$1" "SELECT upper(MIN(currency)) FROM priced ${2:-};"; }
stat_servers()        { sqlite3 "$1" "SELECT COUNT(DISTINCT box) FROM priced ${2:-};"; }
account_price_group() { sqlite3 "$1" "SELECT COALESCE((SELECT price_group FROM detected_group), 'unknown');"; }
stat_total_paid()     { sqlite3 "$1" "SELECT printf('%.2f', SUM(paid)) FROM priced ${2:-};"; }
stat_run_rate()       { sqlite3 "$1" "SELECT printf('%.2f', SUM(CASE WHEN month = (SELECT MAX(month) FROM priced ${2:-}) THEN paid ELSE 0 END)) FROM priced ${2:-};"; }
stat_savings_pct()    { sqlite3 "$1" "SELECT printf('%.1f', (SUM(paid) - SUM(optimal)) * 100.0 / SUM(paid)) FROM priced ${2:-};"; }
stat_savings_amount() { sqlite3 "$1" "SELECT printf('%.0f', round(SUM(paid) - SUM(optimal))) FROM priced ${2:-};"; }

savings_color() {
  if   [ "$1" -ge 50 ]; then printf '%s' "$2"
  elif [ "$1" -ge 20 ]; then printf '%s' "$3"
  else                       printf '%s' "$4"; fi
}

report() {
  local db=$1 grouping=${2:-} filter rule='------------------------------------------------------------------'
  local b='' r='' red='' amber='' green='' prefix bar pct c
  if [ -t 1 ]; then
    b=$'\e[1m'; r=$'\e[0m'
    red=$'\e[1;31m'; amber=$'\e[1;33m'; green=$'\e[1;32m'
  fi
  filter=$(grouping_filter "$grouping")

  printf 'period            : %s%s%s\n'                       "$b" "$(stat_period      "$db" "$filter")" "$r"
  printf 'currency          : %s%s%s  (detected from invoices)\n' "$b" "$(stat_currency "$db" "$filter")" "$r"
  printf 'servers analysed  : %s%s%s\n'                       "$b" "$(stat_servers     "$db" "$filter")" "$r"
  printf 'price group       : %s%s%s\n'                       "$b" "$(account_price_group "$db")" "$r"
  printf 'total paid        : %s€%s%s\n'                      "$b" "$(stat_total_paid  "$db" "$filter")" "$r"
  printf 'current run-rate  : %s€%s%s/mo (last invoice)\n'    "$b" "$(stat_run_rate    "$db" "$filter")" "$r"
  printf '%s\n' "$rule"
  printf 'picking the cheapest same-spec type each month would save : %s%s%%%s  (%s€%s%s)\n' \
         "$b" "$(stat_savings_pct "$db" "$filter")" "$r" "$b" "$(stat_savings_amount "$db" "$filter")" "$r"
  printf '%s\n' "$rule"

  while IFS='|' read -r prefix bar pct; do
    c=$(savings_color "$pct" "$red" "$amber" "$green")
    printf '%s%s%s %s%%%s\n' "$prefix" "$c" "$bar" "$pct" "$r"
  done < <(sqlite3 "$db" <<SQL
SELECT printf('%s  paid %-6.0f optimal %-6.0f |%s|%.0f',
              month, round(SUM(paid)), round(SUM(optimal)),
              substr('########################################', 1,
                     CASE WHEN SUM(paid) > 0
                          THEN MAX(0, CAST((SUM(paid) - SUM(optimal)) * 40.0 / SUM(paid) AS INT))
                          ELSE 0 END),
              round(CASE WHEN SUM(paid) > 0
                   THEN (SUM(paid) - SUM(optimal)) * 100.0 / SUM(paid) ELSE 0 END))
FROM priced $filter
GROUP BY month
ORDER BY month;
SQL
)
}

audit() {
  local assets=$1 data_dir=$2 db="${3:-$2/gelkao.db}" grouping=${4:-}
  build_db "$db" "$assets" "$data_dir"
  report "$db" "$grouping"
}

run_pipeline() {
  local assets=$1 cn=$2 data_dir=${3:-data} db=${4:-} grouping=${5:-} uuids
  uuids=$(extract_uuids || true)
  [[ -n "$uuids" ]] || die "no invoice UUIDs found on stdin"
  printf '%s\n' "$uuids" | fetch_all "$cn" "$data_dir" >&2
  audit "$assets" "$data_dir" "$db" "$grouping"
}
