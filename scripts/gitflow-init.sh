#!/usr/bin/env bash
#
# Configure git-flow (AVH) for this repository's branch model.
#
# The AVH extension reads its settings from git config rather than from a
# tracked file, so the settings cannot be committed directly. This script is
# the committed form: run it once per clone and `git flow` will use the same
# branches and prefixes the repository documents in WORKFLOW.md.
#
# The configuration is plain git config, so this succeeds whether or not the
# extension is installed. Without it, use the equivalent plain-git commands
# documented in WORKFLOW.md.
set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository" >&2
  exit 2
fi

PRODUCTION_BRANCH="main"
INTEGRATION_BRANCH="develop"

git config gitflow.branch.master "$PRODUCTION_BRANCH"
git config gitflow.branch.develop "$INTEGRATION_BRANCH"

git config gitflow.prefix.feature "feature/"
git config gitflow.prefix.bugfix "bugfix/"
git config gitflow.prefix.release "release/"
git config gitflow.prefix.hotfix "hotfix/"
git config gitflow.prefix.support "support/"
git config gitflow.prefix.versiontag "v"

echo "git-flow configured: $PRODUCTION_BRANCH (production) / $INTEGRATION_BRANCH (integration)"

if ! git show-ref --verify --quiet "refs/heads/$INTEGRATION_BRANCH" &&
  ! git show-ref --verify --quiet "refs/remotes/origin/$INTEGRATION_BRANCH"; then
  echo "warning: no '$INTEGRATION_BRANCH' branch found locally or on origin." >&2
  echo "         Create it from $PRODUCTION_BRANCH before starting a feature." >&2
fi

if ! command -v git-flow >/dev/null 2>&1; then
  echo "note: the git-flow AVH extension is not installed."
  echo "      Install it with 'brew install git-flow-avh', or use plain git as"
  echo "      described in WORKFLOW.md."
fi
