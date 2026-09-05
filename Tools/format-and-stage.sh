#!/usr/bin/env bash
# Formats staged Swift files, re-stages them, and never blocks a commit.
set -uo pipefail

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
fi

swift_files=()
for file in "${files[@]}"; do
  if [[ "$file" == *.swift && -f "$file" ]]; then
    swift_files+=("$file")
  fi
done

if [[ ${#swift_files[@]} -eq 0 ]]; then
  exit 0
fi

swift-format -i --configuration .swift-format "${swift_files[@]}" 2>/dev/null || true
swiftlint lint --fix "${swift_files[@]}" 2>/dev/null || true
git add -- "${swift_files[@]}" 2>/dev/null || true
exit 0
