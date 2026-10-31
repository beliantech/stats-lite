#!/bin/bash
#
# Pushes main, creates an annotated release tag, and pushes the tag.
#
# Usage:
#   scripts/tag_release.sh <tag>
#
# Example:
#   scripts/tag_release.sh v1.2.2
#
# The tag must use the repo's vX.Y.Z form. The script refuses to run
# when the local checkout is not on main, when tracked files have
# uncommitted changes, or when the tag already exists locally or on
# origin. All checks run before the first push, so a refused run
# changes nothing.
#
# Order of operations:
#   1. git push origin main
#   2. git tag -a <tag>
#   3. git push origin <tag>
#
# If step 2 or 3 fails, main is already pushed. Delete a stray tag
# with `git tag -d <tag>` before it is pushed, or with
# `git push origin :refs/tags/<tag>` after it is pushed.

set -euo pipefail

usage() {
  echo "Usage: scripts/tag_release.sh <tag>" >&2
  echo "Example: scripts/tag_release.sh v1.2.2" >&2
  exit 2
}

[ "$#" -eq 1 ] || usage
TAG="$1"

if ! [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Error: tag must look like v1.2.2, got '$TAG'." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || {
  echo "Error: checkout is on '$BRANCH', not main." >&2
  exit 1
}

[ -z "$(git status --porcelain --untracked-files=no)" ] || {
  echo "Error: tracked files have uncommitted changes." >&2
  git status --short --untracked-files=no >&2
  exit 1
}

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && {
  echo "Error: tag '$TAG' exists locally." >&2
  exit 1
}

git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null && {
  echo "Error: tag '$TAG' exists on origin." >&2
  exit 1
}

echo "Pushing main to origin..."
git push origin main

echo "Creating annotated tag $TAG..."
git tag -a "$TAG" -m "Release $TAG"

echo "Pushing tag $TAG to origin..."
git push origin "$TAG"

echo "Done: main pushed and tagged $TAG ($(git rev-parse --short HEAD))."
