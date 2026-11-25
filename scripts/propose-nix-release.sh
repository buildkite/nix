#!/usr/bin/env bash
set -euo pipefail

tag=${AGENT_RELEASE_TAG:-}
if [[ ! "$tag" =~ ^v4\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "Expected a stable v4 AGENT_RELEASE_TAG, got: $tag" >&2
  exit 1
fi
version=${tag#v}

repo=buildkite/nix
release_repo=buildkite/agent
base=main
branch="release/nix/${tag}"
manifest=nix/release.json
generator="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/nix-release-manifest.jq"

: "${GH_TOKEN:?Missing Nix publishing credential}"

# The publisher starts in a fresh checkout of the destination's main branch.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
current=$(jq -er '.version' "$manifest")
if [[ "$version" == "$current" || "$(printf '%s\n' "$current" "$version" | sort -V | tail -1)" != "$version" ]]; then
  echo "Skipping Nix bump: main already pins $current (release is $version)"
  exit 0
fi

# A closed PR is a decision, not a reason to create another one on retry.
existing=$(gh api --method GET "repos/$repo/pulls" -f state=all -f base="$base" \
  -f head="${repo%%/*}:$branch" \
  --jq '.[0] | select(. != null) | [.html_url, .state, .head.sha, (.auto_merge != null)] | @tsv')
if [[ -n "$existing" ]]; then
  IFS=$'\t' read -r url pr_state pr_head auto_merge <<< "$existing"
  echo "Nix bump already proposed: $url"
  if [[ "$pr_state" != open ]]; then
    exit 0
  fi
fi

# The Exchange token can write only to the Nix repo. Read public Agent release
# data anonymously so the token is never needed for a second repository.
if ! curl -fsSL "https://api.github.com/repos/$release_repo/releases/tags/$tag" \
  | jq -e '.draft == false and .prerelease == false' >/dev/null; then
  echo "Expected a published stable GitHub release: $tag" >&2
  exit 1
fi
curl -fsSL "https://github.com/$release_repo/releases/download/$tag/buildkite-agent-${version}.SHA256SUMS" \
  | jq -Rs --arg version "$version" -f "$generator" > "$scratch/release.json"

existing_branch=$(git ls-remote --heads origin "refs/heads/$branch")
previous_head=
if [[ -n "$existing_branch" ]]; then
  # A previous run may have pushed the commit but failed to open the PR.
  git fetch --quiet origin "refs/heads/$branch"
  previous_head=$(git rev-parse FETCH_HEAD)
  git show "$previous_head:$manifest" | cmp - "$scratch/release.json"
  fork=$(git merge-base HEAD "$previous_head")
  if [[ "$(git rev-list --count "$fork..$previous_head")" != 1 ||
        "$(git diff --name-only "$fork" "$previous_head")" != "$manifest" ]]; then
    echo "Existing bump branch does not contain a manifest-only commit: $branch" >&2
    exit 1
  fi
fi

head=$previous_head
if [[ -z "$previous_head" || "$fork" != "$(git rev-parse HEAD)" ]]; then
  cp "$scratch/release.json" "$manifest"
  git add -- "$manifest"
  git -c user.name='Buildkite Release' -c user.email='support@buildkite.com' \
    commit -m "Update Nix package to Buildkite Agent $tag"
  # Refresh an unchanged, generated bump on replay if main advanced. A lease
  # prevents replacing edits made after the scope and content checks above.
  git -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
    push --force-with-lease="refs/heads/$branch:$previous_head" origin "HEAD:refs/heads/$branch"
  head=$(git rev-parse HEAD)
fi

if [[ -z "$existing" ]]; then
  url=$(gh pr create --repo "$repo" --base "$base" --head "$branch" \
    --title "Update Nix package to Buildkite Agent $tag" \
    --body "🤖

Pin the Nix package to [Buildkite Agent $tag](https://github.com/${release_repo}/releases/tag/${tag}) using the published SHA-256 checksums. The nixpkgs lock is unchanged.

The Nix release gate must pass before auto-merge.")
elif [[ "$head" == "$pr_head" && "$auto_merge" == true ]]; then
  echo "Auto-merge already enabled: $url"
  exit 0
fi

gh pr merge "$url" --auto --squash --match-head-commit "$head"
