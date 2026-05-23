# shellcheck shell=bash
# Install Tailscale (via Homebrew cask) and bring up the tunnel.

# Path to the tailscale CLI inside the Mac App-style cask install.
TAILSCALE_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

ensure_tailscale_up() {
  if [ ! -x "$TAILSCALE_CLI" ]; then
    log "installing tailscale cask"
    "$BREW" install --cask tailscale
  fi

  # Already logged in and authorized? `tailscale status` exits 0 when up.
  if "$TAILSCALE_CLI" status >/dev/null 2>&1; then
    log "tailscale already up"
    return 0
  fi

  log "bringing tailscale up"
  sudo "$TAILSCALE_CLI" up \
    --authkey="$TS_AUTHKEY" \
    --ssh \
    --accept-routes \
    --hostname="$(hostname -s)"
}
