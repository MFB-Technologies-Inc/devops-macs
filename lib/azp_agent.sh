# shellcheck shell=bash
# Download, configure, and start the Azure DevOps self-hosted agent.
#
# Idempotency: presence of `.agent` inside $AZP_AGENT_DIR indicates the
# agent is already configured; we only (re-)ensure the launchd service is
# loaded in that case.

# TODO: pin a specific agent version once we've picked one. Until then,
# we resolve the latest release tag from GitHub at install time.
AZP_AGENT_DIR="$HOME/azagent"

ensure_azp_agent() {
  if [ -f "$AZP_AGENT_DIR/.agent" ]; then
    log "azp agent already configured at $AZP_AGENT_DIR"
    _ensure_azp_service_running
    return 0
  fi

  log "installing azp agent into $AZP_AGENT_DIR"
  mkdir -p "$AZP_AGENT_DIR"
  cd "$AZP_AGENT_DIR"

  local tarball_url
  tarball_url="$(_resolve_azp_agent_tarball_url)"
  [ -n "$tarball_url" ] || die "could not resolve azp agent tarball URL"

  log "downloading $tarball_url"
  curl -fsSL "$tarball_url" -o agent.tar.gz
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

  _ensure_azp_service_running
}

_resolve_azp_agent_tarball_url() {
  # Latest osx-arm64 release asset from microsoft/azure-pipelines-agent.
  curl -fsSL https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest \
    | grep -oE '"browser_download_url":[[:space:]]*"[^"]+osx-arm64[^"]+\.tar\.gz"' \
    | head -n1 \
    | sed -E 's/.*"(https[^"]+)".*/\1/'
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
