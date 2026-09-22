#!/bin/bash
set -euo pipefail

if [[ ! "$RELEASE_SHA" =~ ^[0-9a-f]{40}$ ]] || [[ "$(git rev-parse HEAD)" != "$RELEASE_SHA" ]]; then
  echo "Checkout does not match the requested release SHA" >&2
  exit 1
fi
tag=$(python3 .github/scripts/release_guard.py tag .)

# Account for both annotated and lightweight tags. Never move an existing tag.
refs=$(git ls-remote --tags origin "refs/tags/$tag" "refs/tags/$tag^{}")
if [[ -n "$refs" ]]; then
  target=$(printf '%s\n' "$refs" | awk 'NR == 1 { object = $1 } /\^\{\}$/ { peeled = $1 } END { print peeled ? peeled : object }')
  if [[ "$target" != "$RELEASE_SHA" ]]; then
    echo "Tag $tag already points to $target, not $RELEASE_SHA" >&2
    exit 1
  fi
  echo "Tag $tag already identifies this release commit"
  exit 0
fi

git tag -a "$tag" "$RELEASE_SHA" -m "Proxmark3 $tag bottles"
git push origin "refs/tags/$tag"
