#!/usr/bin/env bash

UUID_RE='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

die() { echo "error: $*" >&2; exit 1; }

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
  rm -f "$db"
  sqlite3 "$db" < "$assets/schema.sql"
  import_invoices "$db" "$data_dir"
}

report() {
  local n
  n=$(sqlite3 "$1" "SELECT count(*) FROM raw_invoices;")
  printf 'invoice lines loaded: %s\n' "$n"
}

audit() {
  local assets=$1 data_dir=$2 db="${3:-$2/gelkao.db}"
  build_db "$db" "$assets" "$data_dir"
  report "$db"
}

run_pipeline() {
  local assets=$1 cn=$2 data_dir=${3:-data} db=${4:-} uuids
  uuids=$(extract_uuids || true)
  [[ -n "$uuids" ]] || die "no invoice UUIDs found on stdin"
  printf '%s\n' "$uuids" | fetch_all "$cn" "$data_dir" >&2
  audit "$assets" "$data_dir" "$db"
}
