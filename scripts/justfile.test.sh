#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp "$ROOT/justfile" "$TMP/justfile"
cp "$ROOT/.swift-format" "$TMP/.swift-format"
mkdir -p "$TMP/Sources" "$TMP/Tests" "$TMP/bin"
printf 'struct   Sample{}\n' > "$TMP/Sources/Sample.swift"
printf '// Test fixture\n' > "$TMP/Package.swift"

# Formatting warnings must fail the real public check recipe.
if (cd "$TMP" && just format-check) > "$TMP/format.log" 2>&1; then
  echo 'FAIL: format-check accepted unformatted Swift' >&2
  exit 1
fi
swift-format -i --configuration "$TMP/.swift-format" "$TMP/Sources/Sample.swift"
(cd "$TMP" && just format-check)
(cd "$TMP" && just && just default) > /dev/null

# The wrapper must preserve a failed test command through xcbeautify.
printf '#!/usr/bin/env bash\nexit 42\n' > "$TMP/bin/swift"
printf '#!/usr/bin/env bash\ncat\n' > "$TMP/bin/xcbeautify"
chmod +x "$TMP/bin/swift" "$TMP/bin/xcbeautify"
if (cd "$TMP" && PATH="$TMP/bin:$PATH" just test-swift); then
  echo 'FAIL: test-swift swallowed a test failure' >&2
  exit 1
fi

# Keep the established command names and CI aliases available.
for recipe in test-linux test-macos test-ios test-swift test-safe test-tvos \
  test-watchos test-IOS test-MACOS test-TVOS format build build-core build-macros \
  test-core test-macros ci-build clean clean-all docs lint test-all validate \
  setup benchmark benchmark-json coverage help docs-all doc-check \
  doc-check-strict doc-check-json doc-diagrams doc-api doc-examples \
  docs-gen docs-validate; do
  (cd "$TMP" && just --dry-run "$recipe") > /dev/null 2>&1
done

echo 'justfile command and failure-propagation tests passed'
