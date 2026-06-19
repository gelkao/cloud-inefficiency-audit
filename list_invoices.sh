#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  cat data/*.html | ./list_invoices.sh

Extracts Hetzner invoice UUIDs (one per line) from saved invoice HTML read on
stdin. Convention: keep the downloaded invoice pages in the data/ directory.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
esac

uuid_re='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

uuids=$(grep -ohiE "usage\.hetzner\.com/${uuid_re}" "$@" | sed 's|.*/||' || true)

if [[ -z "$uuids" ]]; then
  echo "warning: no UUIDs found — has Hetzner changed the invoice URL?" >&2
  exit 1
fi

printf '%s\n' "$uuids"
