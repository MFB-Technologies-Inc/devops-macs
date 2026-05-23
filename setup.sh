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
# shellcheck source=lib/azp_agent.sh
source "$REPO_DIR/lib/azp_agent.sh"

ensure_apple_silicon_macos

require_env TS_AUTHKEY
require_env AZP_URL
require_env AZP_TOKEN
: "${AZP_POOL:=Default}"
: "${AZP_AGENT_NAME:=$(hostname -s)}"

ensure_xcode_clt
ensure_homebrew
ensure_brew_bundle "$REPO_DIR/Brewfile"
ensure_tailscale_up
ensure_azp_agent

log "Done. Mac is configured as a DevOps runner."
