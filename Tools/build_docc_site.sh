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

if [[ -z "${OUTPUT_PATH:-}" || "$OUTPUT_PATH" == "/" || "$OUTPUT_PATH" == "." || "$OUTPUT_PATH" == ".." ]]; then
  echo "error: OUTPUT_PATH is empty or dangerous: '${OUTPUT_PATH:-}'" >&2
  exit 1
fi
rm -rf "$OUTPUT_PATH"

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
  --output-path "$OUTPUT_PATH"
