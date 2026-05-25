# shellcheck shell=bash
# Configure power management so the runner stays online without intervention.
#
# Goals:
#   - System never sleeps (agent and tailscaled must be reachable at all hours).
#     Display can still blank on its own; we only disable system sleep.
#   - The Mac powers itself back on after a power outage or brownout.
#
# pmset -a applies the setting to every power source (AC + battery + UPS),
# which is the right default for a runner that's expected to stay on
# regardless of what's plugged in. pmset is idempotent; re-running with
# the same values is a no-op.

ensure_power_settings() {
  log "setting power management: never sleep, auto-restart after power loss"
  sudo pmset -a sleep 0
  sudo pmset -a disksleep 0
  sudo pmset -a autorestart 1
}
