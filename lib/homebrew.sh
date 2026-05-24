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

ensure_brew_on_path() {
  # Apple-bundled CLIs (e.g. /usr/bin/git from Xcode CLT) take precedence
  # over Homebrew formulas unless /opt/homebrew/bin appears earlier in PATH.
  # Homebrew's installer prints instructions to do this but doesn't write
  # anything to a profile in non-interactive mode, so we wire it ourselves.
  # Idempotent: only appends the line if it isn't already present.
  local profile="$HOME/.zprofile"
  local line='eval "$(/opt/homebrew/bin/brew shellenv)"'
  touch "$profile"
  if grep -Fqx "$line" "$profile"; then
    log "brew shellenv already wired into $profile"
    return 0
  fi
  log "wiring brew shellenv into $profile"
  printf '\n# Homebrew (added by devops-macs setup.sh)\n%s\n' "$line" >> "$profile"
}
