# Buildkite packages for Nix

This flake is the home for Buildkite's public Nix packages. Select a package
by name; the flake does not have a default package.

## Buildkite Agent

With Nix flakes enabled:

```sh
nix profile add github:buildkite/nix#buildkite-agent
buildkite-agent --version
```

The package installs the checksum-pinned [Buildkite agent release binary](https://github.com/buildkite/agent/releases).
It does not install a service. For checkouts, provide Git on the agent's PATH
(and OpenSSH for SSH repositories). On NixOS you can use the existing nixpkgs
`services.buildkite-agents.<name>.package` option to select this flake's
`packages.${pkgs.stdenv.hostPlatform.system}.buildkite-agent` instead of the
nixpkgs package; the module still configures the service and its environment.

The default ref tracks the current manifest on `main`. Use `nix profile list`
to find the entry name, then `nix profile upgrade <name>` to update just that
entry. Pin a revision with `github:buildkite/nix/<commit>#buildkite-agent` or
add the flake as an input and let your `flake.lock` pin it.

The flake supports amd64 and arm64 on Linux and macOS. The current Intel Mac
output depends on nixpkgs 26.05, the last nixpkgs release to support it.

## Publishing the agent package

The **Publish agent for Nix** job in **Agent - Release - Stable** runs after
GitHub publication passes on `main`, and a Nix failure does not fail the
agent release. The tag selects the binaries; the job runs this repo's publisher
from protected `main`. It opens or reuses a manifest-only PR and requests
auto-merge. Keep `flake.lock` updates in separate, reviewed PRs.

If the gate fails, follow the PR's `buildkite/nix` status to the Buildkite build.
If `main` advanced and GitHub requires an update, retry only the Nix job in the
original release build. It refreshes an unmodified bump branch and skips equal
or older versions. A deliberately closed PR is not reopened.

Require the Buildkite `buildkite/nix` status on up-to-date branches. The
`.buildkite/pipeline.yml` validation pipeline checks published checksums,
evaluates all four outputs, and builds and runs the agent natively on each
platform. It runs on same-repository PRs and needs no publishing credentials.
In the Open Source cluster, Linux amd64 uses `hosted` and macOS arm64 uses
`macos`. Before enabling the gate, provision `nix-linux-arm64` and an isolated
native Intel Mac runner on `nix-macos-amd64`, with Nix 2.35.3 available on the
Intel runner. Buildkite-hosted macOS agents are Apple silicon only.

Keep required CODEOWNERS reviews for everything except the manifest. The
stable release job uses Buildkite Exchange to mint a short-lived GitHub App
token with contents and pull-request write access to `buildkite/nix` only,
without ruleset bypass. Exchange checks the stable pipeline's `publish-nix`
step key and verifies the build commit is on `buildkite/agent` `main`.
If an organisation-level rule requires human approval, auto-merge waits for it.
