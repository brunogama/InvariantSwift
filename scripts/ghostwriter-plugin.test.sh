#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/.llm"
CONSUMER="$(mktemp -d "$ROOT/.llm/ghostwriter-plugin-test.XXXXXX")"
trap 'rm -rf "$CONSUMER"' EXIT
mkdir -p "$CONSUMER/Sources/ConsumerModel"

cat > "$CONSUMER/Package.swift" <<SWIFT
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
  name: "GhostwriterPluginConsumer",
  platforms: [.macOS(.v14)],
  dependencies: [.package(name: "InvariantSwift", path: "$ROOT")],
  targets: [.target(name: "ConsumerModel", dependencies: [
    .product(name: "InvariantSwiftMacroAPI", package: "InvariantSwift"),
    .product(name: "InvariantSwift", package: "InvariantSwift"),
  ])]
)
SWIFT

cat > "$CONSUMER/Sources/ConsumerModel/ConsumerValue.swift" <<'SWIFT'
import InvariantSwift
import InvariantSwiftMacroAPI

@Arbitrary
public struct ConsumerValue: Equatable {
  public let value: Int

  public init(value: Int) {
    self.value = value
  }
}
SWIFT

# Exercise the dependency's command plugin, including SwiftPM's tool build.
# A direct `swift run GhostwriterCLI` does not cover this linker path.
if ! swift package --package-path "$CONSUMER" \
  --allow-writing-to-package-directory ghostwrite --dry-run --verbose \
  > "$CONSUMER/ghostwrite.log" 2>&1; then
  cat "$CONSUMER/ghostwrite.log"
  exit 1
fi

cat "$CONSUMER/ghostwrite.log"
grep -Eq 'Would generate for .*/ConsumerModel/ConsumerValue\.swift:' "$CONSUMER/ghostwrite.log"
grep -Eq 'Tests Generated: [1-9][0-9]*' "$CONSUMER/ghostwrite.log"
test ! -d "$CONSUMER/Tests/Generated"
echo 'Ghostwriter dependency plugin dry-run passed without writing tests.'
