#!/usr/bin/env bash

set -euo pipefail

latest_tag="$(git tag -l 'v*.*.*' --sort=-v:refname | head -1)"

if [[ -n "${latest_tag}" ]]; then
  range="${latest_tag}..HEAD"
  if [[ "$(git rev-list --count "${range}")" -eq 0 ]]; then
    echo "should_release=false"
    exit 0
  fi
  base_version="${latest_tag#v}"
else
  range="HEAD"
  base_version="0.0.0"
fi

log_output="$(git log --format='%s%n%b' "${range}")"
bump="patch"

if grep -Eq '(^[^[:space:]]+(\([^)]+\))?!:)|BREAKING CHANGE:' <<<"${log_output}"; then
  if [[ "${base_version%%.*}" == "0" ]]; then
    bump="minor"
  else
    bump="major"
  fi
elif grep -Eq '^feat(\([^)]+\))?:' <<<"${log_output}"; then
  bump="minor"
fi

IFS='.' read -r major minor patch <<<"${base_version}"

if [[ -z "${latest_tag}" ]]; then
  next_version="0.1.0"
else
  case "${bump}" in
    major)
      next_version="$((major + 1)).0.0"
      ;;
    minor)
      next_version="${major}.$((minor + 1)).0"
      ;;
    patch)
      next_version="${major}.${minor}.$((patch + 1))"
      ;;
  esac
fi

echo "should_release=true"
echo "previous_tag=${latest_tag}"
echo "bump=${bump}"
echo "version=${next_version}"
echo "tag=v${next_version}"
