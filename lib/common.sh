# shellcheck shell=bash
# Common helpers. Source-only — do not execute.

log() {
  printf '[setup] %s\n' "$*"
}

die() {
  printf '[setup] ERROR: %s\n' "$*" >&2
  exit 1
}

require_env() {
  local var_name="$1"
  if [ -z "${!var_name:-}" ]; then
    die "required environment variable $var_name is not set"
  fi
}

ensure_apple_silicon_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "this script only runs on macOS (got $(uname -s))"
  [ "$(uname -m)" = "arm64" ] || die "this script only runs on Apple Silicon (got $(uname -m))"
}

ensure_sudo() {
  # Several steps below need sudo (Homebrew /opt/homebrew dir creation,
  # tailscaled LaunchDaemon, optionally hostname change). Prompt for the
  # password once up front so the rest of the script doesn't fail or stall
  # mid-step. macOS's default sudo timestamp_timeout is ~5 minutes and
  # gets refreshed on every sudo call, so subsequent uses don't re-prompt
  # as long as the script keeps moving.
  log "this script needs sudo for system-level installs (Homebrew, Tailscale daemon, etc.)"
  log "you may be prompted for your password now"
  sudo -v || die "sudo authentication failed"
}
