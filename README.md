# Buildkite packages for Nix

This flake is the home for Buildkite's public Nix packages.

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

The flake supports Linux on amd64 and arm64, and macOS on Apple silicon.

See [Contributing](CONTRIBUTING.md) for development and release details.
