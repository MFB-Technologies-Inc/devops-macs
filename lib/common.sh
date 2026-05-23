# shellcheck shell=bash
# Common helpers. Source-only — do not execute.

log() {
  printf '[setup] %s\n' "$*"
}

die() {
  printf '[setup] ERROR: %s\n' "$*" >&2
  exit 1
}

require_env() {
  local var_name="$1"
  if [ -z "${!var_name:-}" ]; then
    die "required environment variable $var_name is not set"
  fi
}

ensure_apple_silicon_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "this script only runs on macOS (got $(uname -s))"
  [ "$(uname -m)" = "arm64" ] || die "this script only runs on Apple Silicon (got $(uname -m))"
}
