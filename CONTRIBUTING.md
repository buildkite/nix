# Contributing

## Validate a change

With Nix flakes enabled, evaluate all package outputs and build and run the
agent for your current system:

```sh
nix flake check --all-systems --no-build --no-update-lock-file
nix run --no-update-lock-file .#buildkite-agent -- --version
```

Keep `flake.lock` updates in separate, reviewed PRs from agent version bumps.

The [Buildkite pipeline](.buildkite/pipeline.yml) checks the manifest against
published checksums, evaluates all package outputs, and builds and runs the agent
natively on each platform. It runs on same-repository PRs without publishing
credentials. The required `buildkite/nix` status must pass on an up-to-date
branch.

The Open Source cluster uses `hosted` for Linux amd64, `nix-linux-arm64` for
Linux arm64, and `macos` for macOS arm64.

## Publish the agent package

The **Publish agent for Nix** job in **Agent - Release - Stable** runs after
the GitHub release publishes on `main`. A Nix failure does not fail the agent
release. The release tag selects the binaries; the job runs this repo's
[publisher](scripts/propose-nix-release.sh) from protected `main`.

The publisher opens or reuses a PR that changes only
[`nix/release.json`](nix/release.json) and requests auto-merge. CODEOWNERS review
applies to other changes. Auto-merge still waits for the required Buildkite
check and GitHub approvals, including the organisation's required approval.

Buildkite Exchange verifies the stable pipeline's `publish-nix` step key and
that the build commit is on `buildkite/agent` `main`. It issues a short-lived
GitHub App token with contents and pull-request write access to `buildkite/nix`
only, without ruleset bypass.

If validation fails, follow the PR's `buildkite/nix` status to the Buildkite
build. If `main` advanced and GitHub requires an update, retry only the Nix job
in the original release build. It refreshes an unmodified bump branch, skips
equal or older versions, and does not reopen a deliberately closed PR.
