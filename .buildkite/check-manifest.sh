#!/usr/bin/env bash
set -euo pipefail

manifest=nix/release.json
version=$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("version")' "$manifest")
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected a stable version, got $version" >&2
  exit 1
fi

# Compare proposed changes with the exact main commit we just fetched. A bump
# cannot pass with unrelated changes or with a version that main already pins.
git fetch --no-tags origin refs/heads/main
main=$(git rev-parse FETCH_HEAD)
base=$(git merge-base "$main" HEAD)
if [[ "$BUILDKITE_BRANCH" == release/nix/* ]]; then
  if [[ $(git diff --name-only "$main" HEAD) != "$manifest" || "$BUILDKITE_BRANCH" != "release/nix/v$version" ]]; then
    echo 'A Nix release PR must change only the manifest and match its version.' >&2
    exit 1
  fi
fi

if ! git diff --quiet "$base" HEAD -- "$manifest" && git cat-file -e "$main:$manifest" 2>/dev/null; then
  current=$(git show "$main:$manifest" | ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("version")')
  if [[ "$version" == "$current" || $(printf '%s\n' "$current" "$version" | sort -V | tail -1) != "$version" ]]; then
    echo "The Nix manifest must advance the version ($current -> $version)." >&2
    exit 1
  fi
fi

curl -fsSL "https://github.com/buildkite/agent/releases/download/v${version}/buildkite-agent-${version}.SHA256SUMS" \
  | ruby scripts/nix-release-manifest.rb "$version" | diff -u "$manifest" -
