#!/usr/bin/env bash

UUID_RE='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

die() { echo "error: $*" >&2; exit 1; }

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

