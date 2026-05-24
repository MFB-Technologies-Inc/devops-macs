# devops-macs

Idempotent provisioning script for turning an Apple Silicon Mac into a DevOps
runner: Tailscale-connected and registered as a self-hosted Azure DevOps agent.

Re-running the script on an already-configured machine is safe — each step
checks current state and skips work that's already done.

## What it does

1. Verifies the host is Apple Silicon macOS.
2. Installs the Xcode Command Line Tools.
3. Installs Homebrew (if missing) and runs `brew bundle` against the `Brewfile`.
4. Installs Tailscale (formula, not cask) as a system LaunchDaemon — so
   `tailscaled` starts at boot before any user logs in — and joins the
   tailnet via `TS_AUTHKEY` with Tailscale SSH enabled.
5. Downloads, configures, and starts the Azure DevOps agent as a per-user
   launchd service. See "Azure DevOps agent: reboot behavior" below for the
   trade-off between fully-unattended startup and keeping FileVault on.

## Prerequisites

- Apple Silicon Mac (M-series) running a supported macOS.
- An admin user; the script uses `sudo` for system-level installs.
- Network access to GitHub, Homebrew, Tailscale, and your Azure DevOps org.

## Usage

```sh
# Required
export AZP_URL=https://dev.azure.com/your-org
export AZP_TOKEN=...                        # PAT with Agent Pools (read & manage)

# Required only on first run (when the node isn't yet joined to the tailnet)
export TS_AUTHKEY=tskey-auth-...

# Optional
export AZP_POOL="Default"                   # default: Default
export AZP_AGENT_NAME="$(hostname -s)"     # default: short hostname

./setup.sh
```

The script is intended to be re-run any time you want to bring a Mac back to
the canonical runner state — after macOS updates, after manual fiddling, or
when this repo's `Brewfile` / agent version changes. Re-runs after the
initial registration do **not** need `TS_AUTHKEY`; see "Tailscale persistence"
below.

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
- **Used to register a device with key expiry disabled.** Tailnet device
  keys expire by default (typically every 90–180 days); when they do, the
  node has to re-authenticate, which is interactive and breaks a headless
  runner. After the runner first joins, open the Tailscale admin console
  and mark this device as "Disable key expiry" — or apply a tailnet policy
  that exempts runner-tagged devices from expiry.

## Azure DevOps agent: reboot behavior

Unlike `tailscaled`, the AzDO agent's `svc.sh install` creates a **per-user
LaunchAgent** (under `~/Library/LaunchAgents/`), not a system LaunchDaemon.
This is by Microsoft's design — the agent needs access to the user's
keychain and GUI session for Xcode signing, `security` calls, simulator
tests, etc. — but it means the agent does **not** start until the user
has an active login session. After a reboot, the runner stays offline
until someone (or something) logs that user in.

Two valid configurations; pick based on your security posture:

### Option A — Fully unattended (auto-login, no FileVault)

For runners where unattended recovery from reboots matters more than
at-rest disk encryption.

1. **Disable FileVault** if it's on. Auto-login is incompatible with
   FileVault, because the disk can't be unlocked without a password at
   boot. Do this from **System Settings → Privacy & Security → FileVault
   → Turn Off** and wait for decryption to complete.
2. **Enable auto-login** from **System Settings → Users & Groups →
   Automatic login as → \<runner user\>**. macOS prompts for the account
   password to store the auto-login keychain entry.
3. **Reboot once and confirm.** The Mac boots, auto-logs in, and the agent
   appears Online in the Azure DevOps Agent Pools view within a minute.

### Option B — Keep FileVault, accept manual login

For runners holding sensitive data, source, or signing material where
at-rest encryption is non-negotiable. The trade-off is that after every
reboot, a human has to log in (locally or over screen sharing) for the
agent to start. The agent itself is unchanged — the LaunchAgent just
loads on next interactive login.

Neither option is automated by `setup.sh` because both rely on GUI-gated,
password-prompting macOS settings. Once configured, the choice survives
macOS updates.

## Layout

- `setup.sh` — entry point; orchestrates each step.
- `lib/` — one file per concern (`xcode.sh`, `homebrew.sh`, `tailscale.sh`, `azp_agent.sh`), each exposing an `ensure_*` function.
- `Brewfile` — declarative Homebrew package list, applied by `brew bundle`.

## Secrets

Secrets are read from environment variables only — nothing is committed.
The script fails fast if a required variable is missing.
