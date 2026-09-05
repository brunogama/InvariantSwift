#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/scripts/change-budget.sh"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_budget() {
  local name=$1
  local files=$2
  local lines=$3
  local expected_status=$4
  local expected_exit=$5
  local repo="$TMP_DIR/$name"
  local output actual_exit file line

  git init -q "$repo"
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name "Change Budget Test"
  git -C "$repo" commit -q --allow-empty -m baseline

  for ((file = 1; file <= files; file++)); do
    : > "$repo/file-$file.txt"
  done
  for ((line = 1; line <= lines; line++)); do
    file=$(((line - 1) % files + 1))
    printf 'line %d\n' "$line" >> "$repo/file-$file.txt"
  done
  git -C "$repo" add -- "file-"*.txt

  if output=$(cd "$repo" && "$SCRIPT" --json); then
    actual_exit=0
  else
    actual_exit=$?
  fi

  [[ $actual_exit -eq $expected_exit ]] ||
    fail "$name exited $actual_exit, expected $expected_exit: $output"
  [[ $output == *'"files_changed":'"$files"* ]] ||
    fail "$name reported the wrong file count: $output"
  [[ $output == *'"lines_changed":'"$lines"* ]] ||
    fail "$name reported the wrong line count: $output"
  [[ $output == *'"status":"'"$expected_status"'"'* ]] ||
    fail "$name reported the wrong status: $output"
}

assert_budget green-max 10 300 green 0
assert_budget yellow-by-files 11 300 yellow 0
assert_budget yellow-by-lines 10 301 yellow 0
assert_budget yellow-max 25 800 yellow 0
assert_budget red-by-files 26 800 red 1
assert_budget red-by-lines 25 801 red 1

echo "change-budget boundary tests passed"
