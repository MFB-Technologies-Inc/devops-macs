# Claude notes for devops-macs

## What this repo is

A single idempotent shell script (`setup.sh` + `lib/`) that provisions an
Apple Silicon Mac as a DevOps host: Xcode CLT, Homebrew packages with the
brew bin dir wired into PATH, and a headless Tailscale install.

The script intentionally **stops short of installing a CI agent** (Azure
DevOps, GitHub Actions, etc.). Operators install whichever agent they
need manually after the script finishes. This keeps the script vendor-
neutral and avoids dragging in per-CI quirks (auth flows, service install
shapes, FileVault interactions).

The script is the artifact. Anything that isn't the script or directly
supporting it (CI, docs, declarative package lists) doesn't belong here.

## Non-negotiable invariants

- **Idempotent.** Every step must be safe to re-run on an already-configured
  machine. Pattern: each `lib/*.sh` exposes an `ensure_<thing>` function that
  checks current state first and exits early if the work is already done.
  Never write code that errors when something is already installed/configured.
- **Apple Silicon macOS only.** `setup.sh` refuses to run elsewhere. Don't
  add Linux/Intel branches — that's not the target.
- **Secrets via env vars only.** Never read from files in the repo, never
  prompt interactively, never log secret values. Required vars are
  documented in `README.md`; the script fails fast with a clear message if
  any are missing.
- **Bash with `set -euo pipefail`.** Every script (`setup.sh` and each
  `lib/*.sh`) starts with it. No silent failures.

## Conventions

- Each concern lives in its own `lib/*.sh` file, sourced by `setup.sh`.
- Public functions are named `ensure_<thing>` and are idempotent.
- Shared helpers (`log`, `die`, `require_env`) live in `lib/common.sh` and
  are sourced first.
- Use Homebrew for anything that's in Homebrew. Use `Brewfile` for the
  declarative list; only shell-out to `brew install` for things that must
  exist before `brew bundle` runs (e.g., Homebrew itself).
- Apple Silicon Homebrew lives at `/opt/homebrew/bin/brew`. Don't assume
  it's on `PATH` — call it by absolute path inside the script, or `eval`
  its shellenv first.
- **Tailscale must be headless.** Install via the Homebrew formula
  (`brew "tailscale"`), not the cask. Register `tailscaled` as a system
  LaunchDaemon via `sudo brew services start tailscale` so it launches at
  boot before any user logs in. The cask installs a per-user GUI app that
  only starts after a graphical login — wrong shape for a runner. Always
  bring the node up with `--ssh` so we can reach it over Tailscale SSH.
- **Brew-installed CLIs must actually win on PATH.** Just adding a formula
  to `Brewfile` isn't enough — `/usr/bin/git` (and friends) from the Xcode
  CLT take precedence unless `/opt/homebrew/bin` comes first in PATH.
  `ensure_brew_on_path` in `lib/homebrew.sh` wires this into `~/.zprofile`
  for interactive shells. Note that launchd-launched services (including
  any CI agent the operator installs later) get a minimal PATH and do
  **not** inherit `~/.zprofile`; the README documents how operators
  should wire PATH into their agent's own environment.

## When extending

- Adding a package? Put it in `Brewfile`. Don't add a new `lib/` file for it.
- Adding a new system-level concern (e.g., configuring a daemon, registering
  with another service)? Add a `lib/<concern>.sh` with one `ensure_<concern>`
  function, source it from `setup.sh`, and call it from the orchestration
  list. Keep the orchestration ordered: things that other steps depend on
  come first (Xcode CLT before Homebrew; Homebrew before anything brew
  installs).
- Resist re-introducing CI-agent install logic here. If a specific agent
  install proves to be repeatedly hand-rolled across machines and a clear
  case emerges for automating it, raise the question first — the previous
  decision was to keep this repo vendor-neutral. See git log for the
  removal commit's rationale.
- Adding a required env var? Validate it via `require_env` near the top of
  `setup.sh` so the script fails fast, and document it in `README.md`.

## What NOT to do

- Don't add backwards-compatibility shims for older macOS versions or Intel
  Macs. Target is Apple Silicon, current macOS.
- Don't add interactive prompts. The script must run unattended.
- Don't add a "dry-run" or "uninstall" mode unless asked — keeps scope tight.
- Don't commit secrets or `.env` files. `.gitignore` covers these.

## Testing changes

There's no automated test harness — the only real test is running `setup.sh`
on a fresh-ish Mac and on an already-configured Mac and confirming both
end in the same state without errors. When changing a `lib/*.sh`, mentally
walk through both cases before declaring done.
