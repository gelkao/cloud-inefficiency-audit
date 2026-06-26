#!/usr/bin/env bats

setup() {
  # shellcheck source=../badge.sh
  source "$BATS_TEST_DIRNAME/../badge.sh"
}

@test "badge_json reports passing when nothing failed" {
  run badge_json 12 0 2026-06-26
  [ "$status" -eq 0 ]
  [[ "$output" == *'"message":"12 passing · 2026-06-26"'* ]]
  [[ "$output" == *'"color":"success"'* ]]
}

@test "badge_json reports failing when something failed" {
  run badge_json 8 3 2026-06-26
  [[ "$output" == *'"message":"3 failing · 2026-06-26"'* ]]
  [[ "$output" == *'"color":"critical"'* ]]
}

@test "badge_json reports not run when nothing ran" {
  run badge_json 0 0 2026-06-26
  [[ "$output" == *'"message":"not run"'* ]]
  [[ "$output" == *'"color":"lightgrey"'* ]]
}

@test "badge_json emits the shields endpoint schema" {
  run badge_json 1 0 2026-06-26
  [[ "$output" == *'"schemaVersion":1'* ]]
  [[ "$output" == *'"label":"integration"'* ]]
}

@test "count_tap counts passes and failures, excluding skips" {
  run count_tap <<'TAP'
1..4
ok 1 alpha
ok 2 beta # skip no creds
not ok 3 gamma
ok 4 delta
TAP
  [ "$output" = "2 1" ]
}
