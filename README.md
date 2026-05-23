# devops-macs

Idempotent provisioning script for turning an Apple Silicon Mac into a DevOps
runner: Tailscale-connected and registered as a self-hosted Azure DevOps agent.

Re-running the script on an already-configured machine is safe — each step
checks current state and skips work that's already done.

## What it does

1. Verifies the host is Apple Silicon macOS.
2. Installs the Xcode Command Line Tools.
3. Installs Homebrew (if missing) and runs `brew bundle` against the `Brewfile`.
4. Installs and brings up Tailscale, joining the tailnet via `TS_AUTHKEY`.
5. Downloads, configures, and starts the Azure DevOps agent as a launchd service.

## Prerequisites

- Apple Silicon Mac (M-series) running a supported macOS.
- An admin user; the script uses `sudo` for system-level installs.
- Network access to GitHub, Homebrew, Tailscale, and your Azure DevOps org.

## Usage

```sh
# Required
export TS_AUTHKEY=tskey-auth-...           # Tailscale pre-auth key
export AZP_URL=https://dev.azure.com/your-org
export AZP_TOKEN=...                        # PAT with Agent Pools (read & manage)

# Optional
export AZP_POOL="Default"                   # default: Default
export AZP_AGENT_NAME="$(hostname -s)"     # default: short hostname

./setup.sh
```

The script is intended to be re-run any time you want to bring a Mac back to
the canonical runner state — after macOS updates, after manual fiddling, or
when this repo's `Brewfile` / agent version changes.

## Layout

- `setup.sh` — entry point; orchestrates each step.
- `lib/` — one file per concern (`xcode.sh`, `homebrew.sh`, `tailscale.sh`, `azp_agent.sh`), each exposing an `ensure_*` function.
- `Brewfile` — declarative Homebrew package list, applied by `brew bundle`.

## Secrets

Secrets are read from environment variables only — nothing is committed.
The script fails fast if a required variable is missing.
