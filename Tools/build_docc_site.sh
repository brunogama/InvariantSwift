#!/bin/bash

set -euo pipefail

SCHEME="${DOCC_SCHEME:-InvariantSwiftTesting}"
OUTPUT_PATH="${DOCC_OUTPUT_PATH:-site}"
ARCHIVE_NAME="${DOCC_ARCHIVE_NAME:-$SCHEME}"

if [[ -n "${DOCC_HOSTING_BASE_PATH:-}" ]]; then
  HOSTING_BASE_PATH="${DOCC_HOSTING_BASE_PATH}"
elif [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  HOSTING_BASE_PATH="${GITHUB_REPOSITORY#*/}"
else
  HOSTING_BASE_PATH="$(basename "$(pwd)")"
fi

DERIVED_DATA="$(mktemp -d)"
trap 'rm -rf "$DERIVED_DATA"' EXIT

if [[ -z "${OUTPUT_PATH:-}" ]]; then
  echo "error: OUTPUT_PATH is empty" >&2
  exit 1
fi

# Resolve symlinks before verifying the path stays within the project root.
#
# The output directory need not exist yet, so the deepest existing ancestor is
# canonicalised and the remaining components are appended. That still defeats a
# symlinked ancestor, which is what the check below guards against. Written in
# plain bash so the script keeps working where python3 is absent, and it
# validates before creating anything.
resolve_path() {
  local target="$1"
  [[ "$target" == /* ]] || target="$PWD/$target"

  local existing="$target"
  local suffix=""
  local parent
  while [[ ! -d "$existing" ]]; do
    suffix="/$(basename "$existing")$suffix"
    parent="$(dirname "$existing")"
    [[ "$parent" == "$existing" ]] && break
    existing="$parent"
  done

  local base
  base="$(cd -P "$existing" 2>/dev/null && pwd -P)" || return 1
  [[ "$base" == "/" ]] && base=""
  printf '%s\n' "${base}${suffix}"
}

_ROOT="$(pwd -P)"
_RESOLVED="$(resolve_path "$OUTPUT_PATH")"
if [[ -z "$_RESOLVED" || "$_RESOLVED" == "/" ]]; then
  echo "error: OUTPUT_PATH resolves to a dangerous path" >&2
  echo "got: '${_RESOLVED}'" >&2
  exit 1
fi
if [[ "$_RESOLVED" != "$_ROOT"/* ]]; then
  echo "error: OUTPUT_PATH must resolve to a project subdirectory" >&2
  echo "got: '${_RESOLVED}'" >&2
  exit 1
fi

rm -rf "$_RESOLVED"

xcodebuild docbuild \
  -scheme "$SCHEME" \
  -destination 'generic/platform=macOS' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  -derivedDataPath "$DERIVED_DATA"

DOCC_ARCHIVE="$(find "$DERIVED_DATA" -name "${ARCHIVE_NAME}.doccarchive" -print -quit)"

if [[ -z "$DOCC_ARCHIVE" ]]; then
  echo "error: no ${ARCHIVE_NAME}.doccarchive found in $DERIVED_DATA" >&2
  exit 1
fi

xcrun docc process-archive transform-for-static-hosting \
  "$DOCC_ARCHIVE" \
  --hosting-base-path "$HOSTING_BASE_PATH" \
  --output-path "$_RESOLVED"
