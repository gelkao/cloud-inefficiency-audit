#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  echo 00000000-0000-0000-0000-000000000000 | ./fetch_invoices.sh K0000000000

Reads invoice UUIDs on stdin (one per line) and downloads each itemized invoice
as CSV into the data/ directory as <customer-number>-<YYYY-MM>-<uuid>.csv.
Already-downloaded invoices are skipped before downloading, so retries are cheap.

  arg 1 / HETZNER_CN   Hetzner customer number (required)
  OUT_DIR              output directory (default: data)
EOF
}

case "${1-}" in -h|--help) usage; exit 0 ;; esac

CN="${1:-${HETZNER_CN:-}}"
[[ -n "$CN" ]] || die "customer number required (arg or HETZNER_CN env)"

fetch_all "$CN" "${OUT_DIR:-data}"
