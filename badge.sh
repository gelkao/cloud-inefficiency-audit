#!/usr/bin/env bash

GIST_ID=696b0e161d53e5b752b2c6bc7c0fbf74
GIST_FILE=cloud-inefficiency-audit-integration.json

badge_json() {
  local passed=$1 failed=$2 color message
  if (( failed > 0 )); then
    color=critical; message="${failed} failing"
  elif (( passed > 0 )); then
    color=success; message="${passed} passing"
  else
    color=lightgrey; message="not run"
  fi
  printf '{"schemaVersion":1,"label":"integration","message":"%s","color":"%s"}' "$message" "$color"
}

count_tap() {
  local tap passed skipped failed
  tap=$(cat)
  passed=$(grep -cE '^ok '     <<<"$tap" || true)
  skipped=$(grep -cE '# skip'  <<<"$tap" || true)
  failed=$(grep -cE '^not ok ' <<<"$tap" || true)
  printf '%s %s' "$((passed - skipped))" "$failed"
}

push_badge() {
  local json=$1 escaped body
  escaped=${json//\"/\\\"}
  body="{\"files\":{\"$GIST_FILE\":{\"content\":\"$escaped\"}}}"
  printf '%s' "$body" | gh api --method PATCH "gists/$GIST_ID" --input - >/dev/null
}

main() {
  set -uo pipefail
  cd "$(dirname "${BASH_SOURCE[0]}")" || return 1

  echo "==> running integration suite (real downloads — may take a while)" >&2
  local tap passed failed json
  tap=$(bats --formatter tap tests/integration.bats | tee /dev/stderr) || true

  read -r passed failed < <(printf '%s\n' "$tap" | count_tap)
  echo "==> ${passed} passed, ${failed} failed" >&2

  json=$(badge_json "$passed" "$failed")
  echo "==> publishing: $json" >&2
  if push_badge "$json"; then
    echo "==> gist updated" >&2
  else
    echo "ERROR: gist update failed — does gh have the 'gist' scope? try: unset GITHUB_TOKEN; gh auth refresh -s gist" >&2
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
