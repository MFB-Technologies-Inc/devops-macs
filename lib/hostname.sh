# shellcheck shell=bash
# Confirm or change the Mac's hostname before anything else uses it.
#
# Why this exists: a fresh macOS install often picks a hostname like
# "Sam's Mac mini" or "macbook-pro-of-foo", which then becomes the tailnet
# node name when `tailscale up --hostname="$(hostname -s)"` runs. That's
# confusing in `tailscale status` and hard to retroactively rename (each
# rename creates a new tailnet device). Better to ask once at the top.
#
# Interactive by design — this is one of the two intentional prompts in
# the script (the other is sudo). Set SKIP_HOSTNAME_CHECK=1 to bypass
# entirely (useful for fully unattended re-runs).

ensure_hostname() {
  if [ "${SKIP_HOSTNAME_CHECK:-}" = "1" ]; then
    log "skipping hostname check (SKIP_HOSTNAME_CHECK=1); current: $(hostname -s)"
    return 0
  fi

  local current
  current="$(hostname -s)"
  log "current hostname: $current"
  printf '[setup] press Enter to keep, or type a new hostname (lowercase letters, digits, hyphens): '
  local new
  read -r new

  if [ -z "$new" ] || [ "$new" = "$current" ]; then
    log "keeping hostname: $current"
    return 0
  fi

  if ! [[ "$new" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
    die "invalid hostname '$new'; must be 1-63 chars, lowercase letters/digits/hyphens, no leading or trailing hyphen"
  fi

  log "setting hostname to '$new' (HostName, LocalHostName, ComputerName)"
  sudo scutil --set HostName "$new"
  sudo scutil --set LocalHostName "$new"
  sudo scutil --set ComputerName "$new"
  dscacheutil -flushcache 2>/dev/null || true
}
