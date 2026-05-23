# shellcheck shell=bash
# Ensure Homebrew is installed and the Brewfile is applied.

BREW="/opt/homebrew/bin/brew"

ensure_homebrew() {
  if [ -x "$BREW" ]; then
    log "homebrew already installed"
  else
    log "installing homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$("$BREW" shellenv)"
}

ensure_brew_bundle() {
  local brewfile="$1"
  [ -f "$brewfile" ] || die "Brewfile not found at $brewfile"
  log "applying $brewfile"
  "$BREW" bundle --file="$brewfile"
}
