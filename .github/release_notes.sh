#!/usr/bin/env bash
# Release notes from conventional commit subjects in a git range (e.g. v0.5.8..HEAD):
# feat → "Baru", fix → "Perbaikan"; chore/ci/build/docs/test/refactor are left out.
# Usage: .github/release_notes.sh <range>
set -euo pipefail
range=${1:?usage: release_notes.sh <git range>}

section() { # $1 commit type, $2 heading
  local items
  items=$(git log --no-merges --reverse --format='%s' "$range" \
    | grep -E "^$1(\([^)]*\))?!?: " \
    | sed -E 's/^[a-z]+(\([^)]*\))?!?: //; s/^(.)/\U\1/; s/^/- /' || true)
  if [ -n "$items" ]; then printf '%s\n\n%s\n\n' "$2" "$items"; fi
}

notes=$(section feat Baru; section fix Perbaikan)
if [ -n "$notes" ]; then printf '%s\n' "$notes"; else echo "- Perbaikan kecil dan peningkatan stabilitas."; fi
