#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  cat data/*.html | ./gelkao_calc.sh <customer-number>

Runs the whole pipeline: reads invoice HTML on stdin, extracts the invoice
UUIDs, and downloads each invoice as CSV.

  arg 1 / HETZNER_CN   Hetzner customer number (required, e.g. K0000000000)
  DATA_DIR              directory for CSV output (default: data)
EOF
}

case "${1-}" in -h|--help) usage; exit 0 ;; esac

CN="${1:-${HETZNER_CN:-}}"
[[ -n "$CN" ]] || die "customer number required (arg or HETZNER_CN env)"

uuids=$(extract_uuids || true)
[[ -n "$uuids" ]] || die "no invoice UUIDs found on stdin"

printf '%s\n' "$uuids" | fetch_all "$CN" "${DATA_DIR:-data}"
