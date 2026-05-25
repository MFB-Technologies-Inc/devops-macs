# devops-macs

Idempotent provisioning script for turning an Apple Silicon Mac into a
Tailscale-connected DevOps host with a baseline toolchain installed via
Homebrew. CI-agent installation (Azure DevOps, GitHub Actions, etc.) is
left to the operator as a follow-on manual step.

Re-running the script on an already-configured machine is safe — each step
checks current state and skips work that's already done.

## What it does

1. Verifies the host is Apple Silicon macOS.
2. Prompts once for your sudo password and caches it for the run.
3. Shows the current hostname and lets you change it before anything else
   uses it (notably Tailscale, which would otherwise register the tailnet
   node under whatever default macOS picked — e.g. "Sams-Mac-mini"). Press
   Enter to keep, or type a new one.
4. Installs the Xcode Command Line Tools.
5. Installs Homebrew (if missing) and runs `brew bundle` against the `Brewfile`.
6. Wires `/opt/homebrew/bin` ahead of `/usr/bin` in `~/.zprofile` so brew-installed
   CLIs (e.g. `git`) take precedence over the Apple-bundled versions in
   interactive shells.
7. Installs Tailscale (formula, not cask) as a system LaunchDaemon — so
   `tailscaled` starts at boot before any user logs in — and joins the
   tailnet via `TS_AUTHKEY` with Tailscale SSH enabled.

Once the script finishes, the Mac is reachable over Tailscale SSH and has
the baseline toolchain ready. Install your CI agent of choice manually
from that point.

## Prerequisites

- Apple Silicon Mac (M-series) running a supported macOS.
- An admin user; the script uses `sudo` for system-level installs.
- Network access to GitHub, Homebrew, and Tailscale.

## Usage

```sh
# Required only on first run (when the node isn't yet joined to the tailnet)
export TS_AUTHKEY=tskey-auth-...

# Optional: skip the hostname-confirmation prompt (useful for unattended re-runs)
export SKIP_HOSTNAME_CHECK=1

./setup.sh
```

The script is intended to be re-run any time you want to bring a Mac back
to the canonical baseline state — after macOS updates, after manual
fiddling, or when this repo's `Brewfile` changes. Re-runs after the
initial registration do **not** need `TS_AUTHKEY`; see "Tailscale
persistence" below. Re-runs are also unattended-friendly if you set
`SKIP_HOSTNAME_CHECK=1` and have passwordless sudo configured.

## Tailscale persistence and auth key requirements

`TS_AUTHKEY` is a one-time bootstrap credential. On first `tailscale up`,
the coordination server issues a long-lived node key which `tailscaled`
writes to its state file at `/opt/homebrew/var/lib/tailscale/tailscaled.state`
(owned by root). On every subsequent reboot the LaunchDaemon starts
`tailscaled`, which reconnects from that state file — no auth key needed.

For this to keep working unattended, the key you provision with must be:

- **Non-ephemeral.** Ephemeral nodes are removed from the tailnet whenever
  they go offline, which includes every reboot. Use a reusable, non-ephemeral
  auth key from the Tailscale admin console.
- **Tagged with our standard devops-server tag.** When generating the
  auth key in the Tailscale admin console, attach the tag we use for
  devops servers (the operator setting the runner up will know which one).
  The auth key applies that tag to the device on registration; tagged
  nodes don't go through the usual 90–180 day key-expiry cycle that would
  otherwise force an interactive re-auth and knock a headless runner
  offline. As a bonus, tailnet ACLs can grant access uniformly to every
  tagged runner.

## Installing a CI agent (operator follow-up)

After `setup.sh` finishes, install whichever CI agent the runner is meant
to host (Azure DevOps, GitHub Actions, Buildkite, etc.) following that
vendor's instructions. A couple of gotchas worth knowing regardless of
which agent you pick:

- **PATH in launchd-launched agents.** macOS launchd hands services a
  minimal PATH that excludes `/opt/homebrew/bin`. If you want your CI
  jobs to use the brew-installed `git` (and other brew tools), wire
  `/opt/homebrew/bin` into the agent's environment — for the Azure DevOps
  agent that means writing a `.env` file in the agent root containing
  `PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`,
  then restarting the agent service. Other agents have their own equivalent.
- **Reboot recovery vs. FileVault.** Most macOS CI agents install as
  per-user LaunchAgents and only start after a graphical login. To make
  reboots fully unattended you typically disable FileVault and enable
  Automatic login for the runner account. If on-disk encryption matters
  more than unattended reboots, accept that a human has to log in after
  each reboot for the agent to come online.

## Layout

- `setup.sh` — entry point; orchestrates each step.
- `lib/` — one file per concern (`hostname.sh`, `xcode.sh`, `homebrew.sh`, `tailscale.sh`), each exposing an `ensure_*` function.
- `Brewfile` — declarative Homebrew package list, applied by `brew bundle`.

## Secrets

Secrets are read from environment variables only — nothing is committed.
The script fails fast if a required variable is missing.
