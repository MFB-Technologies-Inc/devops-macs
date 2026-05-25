#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/xcode.sh
source "$REPO_DIR/lib/xcode.sh"
# shellcheck source=lib/homebrew.sh
source "$REPO_DIR/lib/homebrew.sh"
# shellcheck source=lib/tailscale.sh
source "$REPO_DIR/lib/tailscale.sh"

ensure_apple_silicon_macos

# TS_AUTHKEY is required only if the node isn't already joined to the tailnet,
# so _ensure_tailnet_joined checks for it on demand. tailscaled persists node
# identity in its state file across reboots, so re-runs after first boot
# don't need the auth key.

ensure_xcode_clt
ensure_homebrew
ensure_brew_bundle "$REPO_DIR/Brewfile"
ensure_brew_on_path
ensure_tailscale_up

log "Done. Mac is provisioned. Install the CI agent manually as the next step."
