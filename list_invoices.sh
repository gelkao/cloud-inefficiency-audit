#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  cat data/*.html | ./list_invoices.sh

Extracts Hetzner invoice UUIDs (one per line) from saved invoice HTML read on
stdin. Convention: keep the downloaded invoice pages in the data/ directory.
EOF
}

case "${1-}" in -h|--help) usage; exit 0 ;; esac

list_invoices "$@"
