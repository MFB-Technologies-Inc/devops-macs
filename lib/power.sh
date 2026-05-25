# shellcheck shell=bash
# Configure power management so the runner stays online without intervention.
#
# Goals:
#   - System never sleeps (agent and tailscaled must be reachable at all hours).
#     Display can still blank on its own; we only disable system sleep.
#   - The Mac is on whenever it can be. `pmset autorestart 1` covers the
#     AC-lost-then-restored case (firmware-level), but does NOT cover a
#     clean shutdown via the Apple menu — there's no power-failure event
#     to trigger on. To close that gap, schedule a daily power-on; if the
#     Mac ever ends up off for any reason it comes back up within ~24h.
#
# pmset -a applies the setting to every power source (AC + battery + UPS),
# which is the right default for a runner that's expected to stay on
# regardless of what's plugged in. pmset is idempotent; re-running with
# the same values is a no-op.

POWER_ON_TIME="06:00:00"  # 24h local time; adjust if 6am conflicts with anything

ensure_power_settings() {
  log "setting power management: never sleep, auto-restart, daily power-on at $POWER_ON_TIME"
  sudo pmset -a sleep 0
  sudo pmset -a disksleep 0
  sudo pmset -a autorestart 1
  # Daily power-on every day of the week. `pmset repeat` replaces any
  # existing repeat schedule, so this is idempotent across re-runs.
  sudo pmset repeat poweron MTWRFSU "$POWER_ON_TIME"
}
