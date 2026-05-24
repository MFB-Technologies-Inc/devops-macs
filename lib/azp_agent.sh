# shellcheck shell=bash
# Download, configure, and start the Azure DevOps self-hosted agent.
#
# We pin the bootstrap agent version and download from Microsoft's official
# distribution endpoint (download.agent.dev.azure.com). Once the agent is
# registered, the Azure DevOps server pushes updates to it in place, so
# this pinned version only governs the *first* install.
#
# Idempotency: presence of `.agent` inside $AZP_AGENT_DIR indicates the
# agent is already configured; we only (re-)ensure the launchd service is
# loaded in that case.

AZP_AGENT_VERSION="4.273.0"
AZP_AGENT_DIR="$HOME/myagent"
AZP_AGENT_URL="https://download.agent.dev.azure.com/agent/${AZP_AGENT_VERSION}/vsts-agent-osx-arm64-${AZP_AGENT_VERSION}.tar.gz"

ensure_azp_agent() {
  if [ ! -f "$AZP_AGENT_DIR/.agent" ]; then
    _install_and_configure_azp_agent
  else
    log "azp agent already configured at $AZP_AGENT_DIR"
  fi
  _ensure_azp_agent_env
  _ensure_azp_service_running
}

_install_and_configure_azp_agent() {
  log "installing azp agent $AZP_AGENT_VERSION into $AZP_AGENT_DIR"
  mkdir -p "$AZP_AGENT_DIR"
  cd "$AZP_AGENT_DIR"

  log "downloading $AZP_AGENT_URL"
  curl -fsSL "$AZP_AGENT_URL" -o agent.tar.gz
  tar xzf agent.tar.gz
  rm -f agent.tar.gz

  log "configuring agent against $AZP_URL pool=$AZP_POOL name=$AZP_AGENT_NAME"
  ./config.sh \
    --unattended \
    --url "$AZP_URL" \
    --auth pat \
    --token "$AZP_TOKEN" \
    --pool "$AZP_POOL" \
    --agent "$AZP_AGENT_NAME" \
    --acceptTeeEula \
    --replace
}

_ensure_azp_agent_env() {
  # The AzDO agent reads $AGENT_HOME/.env at process startup and exports
  # those variables to the task environment. launchd otherwise gives the
  # agent a minimal PATH that excludes /opt/homebrew/bin, so build steps
  # would resolve `git` to /usr/bin/git (Xcode CLT) instead of the
  # brew-installed version. Putting /opt/homebrew/bin first fixes that for
  # every tool we install via Brewfile.
  local envfile="$AZP_AGENT_DIR/.env"
  if [ -f "$envfile" ]; then
    log "agent .env already exists; leaving as-is"
    return 0
  fi
  log "writing agent .env with Homebrew PATH precedence"
  cat > "$envfile" <<'EOF'
# Environment for the Azure DevOps agent process. Read at agent startup;
# exported to every task this agent runs. Edit and then restart the agent
# service for changes to take effect:
#   cd ~/myagent && sudo ./svc.sh stop && sudo ./svc.sh start
PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
EOF
}

_ensure_azp_service_running() {
  cd "$AZP_AGENT_DIR"
  # svc.sh installs a launchd service under the current user.
  if ./svc.sh status 2>/dev/null | grep -qi 'running'; then
    log "azp agent service already running"
    return 0
  fi
  log "installing and starting azp agent launchd service"
  sudo ./svc.sh install
  sudo ./svc.sh start
}
