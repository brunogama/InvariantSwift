#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
REPO=$(mktemp -d); trap 'rm -rf "$REPO"' EXIT
git init -q "$REPO"
git -C "$REPO" config user.email a@b.c; git -C "$REPO" config user.name Test
git -C "$REPO" commit -q --allow-empty -m baseline
git -C "$REPO" tag v0.4.2
git -C "$REPO" commit -q --allow-empty -m 'feat!: break API'
output=$(cd "$REPO" && bash "$ROOT/Tools/release/next_version.sh")
[[ $output == *"bump=minor"* && $output == *"version=0.5.0"* ]]
