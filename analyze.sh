#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  ./analyze.sh [data_dir]

Builds a throwaway SQLite database from the invoice CSVs and prints the result.
  arg 1 / DATA_DIR   invoice CSV folder (default: data)
  DB                 database path (default: data/gelkao.db)
EOF
}

case "${1-}" in -h|--help) usage; exit 0 ;; esac

analyze "$here" "${1:-${DATA_DIR:-data}}" "${DB:-}"
