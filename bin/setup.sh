#!/usr/bin/env bash

# setup.sh – Elixir + asdf environment with Hex connectivity diagnostics
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

section() {
  echo
  echo "==== $* ===="
}

log() {
  echo "[$(date -Iseconds)] $*"
}

check_url() {
  local name="$1"
  local url="$2"

  section "Connectivity check: $name ($url)"

  if ! command -v curl >/dev/null 2>&1; then
    log "curl not found; installing curl and ca-certificates…"
    apt-get update -qq
    apt-get install -y --no-install-recommends curl ca-certificates
  fi

  # We want the HTTP code and some timing info
  set +e
  local out
  out=$(curl -sS -o /dev/null \
    -w 'http_code=%{http_code} remote_ip=%{remote_ip} time_connect=%{time_connect} time_total=%{time_total} ssl_verify_result=%{ssl_verify_result}\n' \
    --max-time 15 --connect-timeout 5 "$url" 2>&1)
  local status=$?
  set -e

  if [ $status -ne 0 ]; then
    log "❌ curl failed (exit code $status)"
    log "    Output: $out"
    log "    This usually means DNS / proxy / TLS issues."
    return $status
  fi

  log "✅ curl succeeded:"
  log "    $out"
}

section "Base system packages"

apt-get update -qq
apt-get install -y --no-install-recommends \
  git curl ca-certificates \
  libssl3 zlib1g libncurses6 \
  build-essential

section "Installing asdf"

if [ ! -d /opt/asdf ]; then
  log "Cloning asdf into /opt/asdf…"
  git clone -q https://github.com/asdf-vm/asdf.git /opt/asdf --branch v0.14.1
else
  log "asdf already present in /opt/asdf, skipping clone."
fi

# shellcheck disable=SC1091
. /opt/asdf/asdf.sh

section "Adding asdf plugins (Erlang/Elixir/Node)"

# Erlang: use prebuilt binaries for speed; swap plugin if this ever breaks
asdf plugin add erlang https://github.com/michallepicki/asdf-erlang-prebuilt-ubuntu-24.04.git 2>/dev/null || log "erlang plugin already added."
asdf plugin add elixir 2>/dev/null || log "elixir plugin already added."
asdf plugin add nodejs 2>/dev/null || log "nodejs plugin already added."

section "Installing tools from .tool-versions"

if [ ! -f .tool-versions ]; then
  log "⚠ .tool-versions not found in current directory: $(pwd)"
  log "   Make sure setup.sh is run from the project root."
else
  log "Using .tool-versions:"
  cat .tool-versions
fi

asdf install
asdf reshim

section "Tool versions"

log "Erlang:"
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell || log "Could not run erl."
log "Elixir:"
elixir -v || true
log "Node:"
node -v || true

section "Environment / proxy overview"

env | grep -Ei '^(http|https)_proxy=|^no_proxy=|^MIX_|^HEX_' || log "No proxy / MIX / HEX-related env vars set."

section "Connectivity diagnostics (GitHub & Hex.pm)"

# GitHub for Hex archive installation
check_url "GitHub (hexpm/hex)" "https://github.com/hexpm/hex" || true

# Hex.pm API – what mix deps.get normally talks to
check_url "Hex.pm API" "https://hex.pm/api/packages/hex" || true

section "Installing Hex via GitHub"

set +e
mix archive.install github hexpm/hex --branch latest --force
hex_status=$?
set -e

if [ $hex_status -ne 0 ]; then
  log "❌ mix archive.install github hexpm/hex failed with status $hex_status"
  log "   Likely causes in Codex:"
  log "   - GitHub blocked / rate limited"
  log "   - TLS / proxy problems"
  log "   - No outbound network from this environment"
else
  log "✅ Hex archive installed successfully."
  section "Verifying Hex (mix hex.info)"
  set +e
  mix hex.info
  hex_info_status=$?
  set -e
  if [ $hex_info_status -ne 0 ]; then
    log "⚠ mix hex.info failed with status $hex_info_status"
    log "   Hex is installed but could not talk to hex.pm."
  else
    log "✅ mix hex.info succeeded – Hex can reach hex.pm."
  fi
fi

section "Final notes"

log "If later 'mix deps.get' fails, scroll up to:"
log "  - The 'Connectivity diagnostics' section for HTTP/TLS details"
log "  - The Hex install + hex.info logs for exact errors"
log "Elixir toolchain is set up; dependency fetching depends on Codex network rules."

log "✅ setup.sh finished."
