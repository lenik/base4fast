#!/bin/bash
# Runs inside the build4 target container before the compile step.
# Installs a toolchain capable of building bas-c + getbar + repoman.
# Apt sources come from the suite bootstrap list mounted by build-lrm-tools.sh.

set -euo pipefail

log() { printf 'build4-prescript: %s\n' "$*" >&2; }

# Merge suite apt.conf snippets (e.g. Check-Valid-Until for archives).
if [[ -d /etc/apt/apt.conf.d/suite ]]; then
  cp -a /etc/apt/apt.conf.d/suite/. /etc/apt/apt.conf.d/
fi

export DEBIAN_FRONTEND=noninteractive

log "apt-get update"
apt-get update

# Runtime/build deps. Package names differ slightly across Debian generations.
pkgs=(
  bash
  ca-certificates
  build-essential
  pkg-config
  meson
  ninja-build
  git
  gettext
  libcurl4-openssl-dev
  libssl-dev
  zlib1g-dev
  libglib2.0-dev
  libicu-dev
  bash-builtins
  python3
  locales
)

log "installing build dependencies"
apt-get install -y --no-install-recommends "${pkgs[@]}"

# Prefer a UTF-8 locale (Meson warns/errors on ANSI_X3.4-1968).
if [[ -f /etc/locale.gen ]] && ! grep -q '^en_US.UTF-8' /etc/locale.gen 2>/dev/null; then
  sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen || true
  locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
fi
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

command -v meson >/dev/null
command -v ninja >/dev/null
log "ready: meson $(meson --version | head -1), ninja $(ninja --version | head -1)"
