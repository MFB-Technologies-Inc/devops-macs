# shellcheck shell=bash
# Ensure Xcode Command Line Tools are installed.

ensure_xcode_clt() {
  if /usr/bin/xcode-select -p >/dev/null 2>&1; then
    log "xcode CLT already installed"
    return 0
  fi

  log "installing xcode CLT (may show a GUI prompt)"
  # Touch this file so softwareupdate exposes the CLT as an available update,
  # then install it non-interactively. This is the standard CI-friendly path.
  local sentinel="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$sentinel"
  local label
  label="$(softwareupdate -l 2>/dev/null \
    | grep -E 'Command Line Tools' \
    | tail -n1 \
    | sed -E 's/^[[:space:]]*\*?[[:space:]]*Label:[[:space:]]*//')"
  if [ -n "$label" ]; then
    sudo softwareupdate -i "$label" --verbose
  else
    log "no CLT label found via softwareupdate; falling back to xcode-select --install"
    xcode-select --install || true
    until /usr/bin/xcode-select -p >/dev/null 2>&1; do
      sleep 10
    done
  fi
  sudo rm -f "$sentinel"
  log "xcode CLT installed"
}
