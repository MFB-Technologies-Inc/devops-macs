# Declarative Homebrew package list applied by `brew bundle`.
# Add packages here rather than calling `brew install` from shell.

brew "git"
brew "jq"
brew "curl"
brew "wget"

# Headless tailscaled. We use the formula (not the cask) so it can run as
# a system LaunchDaemon that starts at boot, before any user logs in.
# See lib/tailscale.sh for the service install and `tailscale up` invocation.
brew "tailscale"
