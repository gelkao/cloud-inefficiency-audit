#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  cat data/*.html | ./gelkao_calc.sh <customer-number>

Runs the whole pipeline: reads invoice HTML on stdin, extracts the invoice
UUIDs, downloads each invoice as CSV, then analyzes them.

  arg 1 / HETZNER_CN   Hetzner customer number (required, e.g. K0000000000)
  DATA_DIR              directory for CSV output (default: data)
  DB                    database path (default: data/gelkao.db)
EOF
}

case "${1-}" in -h|--help) usage; exit 0 ;; esac

CN="${1:-${HETZNER_CN:-}}"
[[ -n "$CN" ]] || die "customer number required (arg or HETZNER_CN env)"

uuids=$(extract_uuids || true)
[[ -n "$uuids" ]] || die "no invoice UUIDs found on stdin"

data_dir="${DATA_DIR:-data}"
printf '%s\n' "$uuids" | fetch_all "$CN" "$data_dir" >&2
analyze "$here" "$data_dir" "${DB:-}"
