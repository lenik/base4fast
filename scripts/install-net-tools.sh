#!/bin/bash
# Install common network utilities; skip packages that do not exist on this OS.
# Usage: install-net-tools.sh
set -euo pipefail

log() { printf 'install-net-tools: %s\n' "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# Candidate package names per tool (first available wins per group… we try all).
# shellcheck disable=SC2034
DEBIAN_PKGS=(
  iputils-ping
  curl
  net-tools
  netcat-openbsd
  netcat-traditional
  nmap
  dnsutils
  proxychains4
  proxychains
  shadowsocks-libev
  shadowsocks
  privoxy
)

RPM_PKGS=(
  iputils
  curl
  net-tools
  nmap-ncat
  nmap
  bind-utils
  proxychains-ng
  proxychains
  shadowsocks-libev
  shadowsocks-rust
  privoxy
)

# openSUSE / SLES
ZYPPER_PKGS=(
  iputils
  curl
  net-tools-deprecated
  netcat-openbsd
  nmap
  bind-utils
  proxychains-ng
  shadowsocks-libev
  privoxy
)

try_apt() {
  local pkg
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq || true
  for pkg in "${DEBIAN_PKGS[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      if apt-get install -y --no-install-recommends "$pkg"; then
        log "installed $pkg"
      else
        log "skip $pkg (install failed)"
      fi
    else
      log "skip $pkg (not in apt cache)"
    fi
  done
}

try_dnf_yum() {
  local pkg mgr=dnf
  have dnf || mgr=yum
  for pkg in "${RPM_PKGS[@]}"; do
    if $mgr -y --setopt=install_weak_deps=False install "$pkg"; then
      log "installed $pkg"
    else
      log "skip $pkg"
    fi
  done
}

try_zypper() {
  local pkg
  zypper --non-interactive refresh || true
  for pkg in "${ZYPPER_PKGS[@]}"; do
    if zypper --non-interactive install -y --no-recommends "$pkg"; then
      log "installed $pkg"
    else
      log "skip $pkg"
    fi
  done
}

main() {
  if have apt-get; then
    try_apt
  elif have dnf || have yum; then
    try_dnf_yum
  elif have zypper; then
    try_zypper
  else
    log "no supported package manager"
    exit 0
  fi
  log "done"
}

main "$@"
