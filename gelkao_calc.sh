#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  ./gelkao_calc.sh <customer-number>

Runs the whole pipeline: extracts invoice UUIDs from the saved invoice HTML in
the input directory and downloads each invoice as CSV.

  arg 1 / HETZNER_CN   Hetzner customer number (required, e.g. K0000000000)
  DATA_DIR             directory of saved invoice HTML (default: data)
  OUT_DIR              directory for CSV output           (default: data)
EOF
}

case "${1-}" in -h|--help) usage; exit 0 ;; esac

CN="${1:-${HETZNER_CN:-}}"
[[ -n "$CN" ]] || die "customer number required (arg or HETZNER_CN env)"

data_dir="${DATA_DIR:-data}"

shopt -s nullglob
html=( "$data_dir"/*.html )
shopt -u nullglob
[[ ${#html[@]} -gt 0 ]] || die "no HTML files in $data_dir/ — save invoice pages there first"

uuids=$(extract_uuids "${html[@]}" || true)
[[ -n "$uuids" ]] || die "no invoice UUIDs found in $data_dir/*.html"

printf '%s\n' "$uuids" | fetch_all "$CN" "${OUT_DIR:-data}"
