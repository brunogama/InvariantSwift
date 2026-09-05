#!/usr/bin/env bash
set -euo pipefail

MODE="staged"
BASE=""
HEAD_REF=""
OUTPUT="text"
WARN_FILES=10
WARN_LINES=300
FAIL_FILES=25
FAIL_LINES=800

usage() {
  cat <<USAGE
Usage: $0 [--mode staged|head|range] [--base <ref>] [--head <ref>] [--json]

Modes:
  --mode staged   Check staged changes (default)
  --mode head     Check the last commit (HEAD~1..HEAD)
  --mode range    Check an explicit range using --base and --head

Thresholds:
  warn at  ${WARN_FILES} files or ${WARN_LINES} lines
  fail at  ${FAIL_FILES} files or ${FAIL_LINES} lines
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --base)
      BASE="$2"
      shift 2
      ;;
    --head)
      HEAD_REF="$2"
      shift 2
      ;;
    --json)
      OUTPUT="json"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository" >&2
  exit 2
fi

case "$MODE" in
  staged)
    DIFF_ARGS=(--cached)
    ;;
  head)
    DIFF_ARGS=(HEAD~1 HEAD)
    ;;
  range)
    if [[ -z "$BASE" || -z "$HEAD_REF" ]]; then
      echo "--mode range requires --base and --head" >&2
      exit 2
    fi
    DIFF_ARGS=("$BASE" "$HEAD_REF")
    ;;
  *)
    echo "Invalid mode: $MODE" >&2
    exit 2
    ;;
esac

FILES_CHANGED=$(git diff --name-only "${DIFF_ARGS[@]}" | sed '/^$/d' | wc -l | tr -d ' ')
SHORTSTAT=$(git diff --shortstat "${DIFF_ARGS[@]}" || true)
ADDED=$(echo "$SHORTSTAT" | sed -n 's/.* \([0-9][0-9]*\) insertion.*/\1/p')
DELETED=$(echo "$SHORTSTAT" | sed -n 's/.* \([0-9][0-9]*\) deletion.*/\1/p')
ADDED=${ADDED:-0}
DELETED=${DELETED:-0}
TOTAL_LINES=$((ADDED + DELETED))

STATUS="green"
EXIT_CODE=0
if (( FILES_CHANGED > FAIL_FILES || TOTAL_LINES > FAIL_LINES )); then
  STATUS="red"
  EXIT_CODE=1
elif (( FILES_CHANGED > WARN_FILES || TOTAL_LINES > WARN_LINES )); then
  STATUS="yellow"
fi

if [[ "$OUTPUT" == "json" ]]; then
  printf '{"mode":"%s","files_changed":%d,"lines_added":%d,"lines_deleted":%d,"lines_changed":%d,"status":"%s"}\n' \
    "$MODE" "$FILES_CHANGED" "$ADDED" "$DELETED" "$TOTAL_LINES" "$STATUS"
else
  echo "mode: $MODE"
  echo "files changed: $FILES_CHANGED"
  echo "lines added: $ADDED"
  echo "lines deleted: $DELETED"
  echo "lines changed: $TOTAL_LINES"
  echo "status: $STATUS"
  echo "warn threshold: ${WARN_FILES} files or ${WARN_LINES} lines"
  echo "fail threshold: ${FAIL_FILES} files or ${FAIL_LINES} lines"
fi

exit "$EXIT_CODE"
