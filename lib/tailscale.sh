# shellcheck shell=bash
# Install Tailscale headlessly and bring up the tunnel with Tailscale SSH.
#
# We use the Homebrew *formula* (`brew "tailscale"` in Brewfile), not the
# cask. The cask installs the GUI Tailscale.app, which runs as a per-user
# LaunchAgent and only starts after a graphical login — useless for a
# headless runner that must be reachable after reboot before anyone logs in.
#
# The formula ships `tailscaled` + the `tailscale` CLI. We register
# tailscaled as a *system* LaunchDaemon under /Library/LaunchDaemons via
# `sudo brew services start tailscale`, so it launches at boot as root,
# independent of any user session.

TAILSCALE="/opt/homebrew/bin/tailscale"

ensure_tailscale_up() {
  # The tailscale formula is declared in Brewfile and installed by
  # ensure_brew_bundle, so the CLI is expected to exist by this point.
  [ -x "$TAILSCALE" ] || die "tailscale CLI not found at $TAILSCALE; check Brewfile"

  _ensure_tailscaled_daemon
  _ensure_tailnet_joined
}

_ensure_tailscaled_daemon() {
  if pgrep -x tailscaled >/dev/null 2>&1; then
    log "tailscaled already running"
    return 0
  fi
  log "starting tailscaled as a system LaunchDaemon"
  # `sudo brew services` writes to /Library/LaunchDaemons (system-wide,
  # starts at boot). The non-sudo form writes to ~/Library/LaunchAgents
  # (per-user, requires login) — explicitly not what we want.
  sudo "$BREW" services start tailscale
  local i=0
  until pgrep -x tailscaled >/dev/null 2>&1 || [ $i -ge 15 ]; do
    sleep 1
    i=$((i + 1))
  done
  pgrep -x tailscaled >/dev/null 2>&1 || die "tailscaled failed to start"
}

_ensure_tailnet_joined() {
  # `tailscale status` exits 0 only when the node is authenticated and
  # connected to the tailnet. Logged-out or unauthenticated returns non-zero.
  if sudo "$TAILSCALE" status >/dev/null 2>&1; then
    log "tailnet already joined"
    return 0
  fi
  log "joining tailnet (Tailscale SSH enabled)"
  sudo "$TAILSCALE" up \
    --authkey="$TS_AUTHKEY" \
    --ssh \
    --accept-routes \
    --hostname="$(hostname -s)"
}
