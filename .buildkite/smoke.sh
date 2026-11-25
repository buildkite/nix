#!/usr/bin/env bash
set -euo pipefail

system=$1
case "$system" in
  x86_64-linux)   native=Linux:x86_64 ;;
  aarch64-linux)  native=Linux:aarch64 ;;
  x86_64-darwin)  native=Darwin:x86_64 ;;
  aarch64-darwin) native=Darwin:arm64 ;;
esac
if [[ "$(uname -s):$(uname -m)" != "$native" ]] ||
   [[ "$system" == x86_64-darwin && "$(sysctl -in sysctl.proc_translated)" == 1 ]]; then
  echo "Expected a native $system runner" >&2
  exit 1
fi

if ! command -v nix >/dev/null; then
  # Hosted jobs are disposable. Persistent runners should provision Nix on the
  # image instead. This release is the last installer with Intel Mac binaries.
  scratch=$(mktemp -d)
  trap 'rm -rf "$scratch"' EXIT
  curl -fsSL https://releases.nixos.org/nix/nix-2.35.3/install -o "$scratch/install"
  printf '%s  %s\n' 69d0fe8fba8fe88f94c98b09964691ac9950abc7ecbf2ba861dc0533cfd901e9 "$scratch/install" | shasum -a 256 -c -
  if [[ "$system" == *-darwin ]]; then
    bash "$scratch/install" --daemon --yes --no-channel-add --no-modify-profile
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  else
    sudo install -d -o "$(id -u)" /nix
    bash "$scratch/install" --no-daemon --no-channel-add --no-modify-profile
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
fi

export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'
if [[ $(nix eval --impure --raw --expr builtins.currentSystem) != "$system" ]]; then
  echo "Expected Nix to target $system" >&2
  exit 1
fi
if [[ "$system" == x86_64-linux ]]; then
  nix flake check --all-systems --no-build --no-update-lock-file .
fi
expected=$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("version")' nix/release.json)
out=$(nix build --no-link --print-out-paths --no-update-lock-file .#buildkite-agent)
actual=$("$out/bin/buildkite-agent" --version)
echo "$actual"
if [[ "$actual" != "buildkite-agent version $expected" && "$actual" != "buildkite-agent version $expected+"?* ]]; then
  echo "Expected Buildkite Agent $expected" >&2
  exit 1
fi
