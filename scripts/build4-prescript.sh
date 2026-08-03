#!/bin/bash
# Runs inside the build4 Debian/Ubuntu target container before the compile step.
# Installs a toolchain capable of building bas-c + getbar + repoman.
# Apt sources come from the suite bootstrap list mounted by build-lrm-tools.sh.

set -euo pipefail

log() { printf 'build4-prescript: %s\n' "$*" >&2; }

# Dockerd pull-proxy must not apply to apt inside the build container.
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy 2>/dev/null || true

# Merge suite apt.conf snippets (e.g. Check-Valid-Until for archives).
if [[ -d /etc/apt/apt.conf.d/suite ]]; then
  cp -a /etc/apt/apt.conf.d/suite/. /etc/apt/apt.conf.d/
fi

export DEBIAN_FRONTEND=noninteractive

# build4 may bind-mount host apt caches; a killed container can leave stale locks.
rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock \
  /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend 2>/dev/null || true

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
# bash-builtins is missing on some Ubuntu releases; retry without it.
if ! apt-get install -y --no-install-recommends "${pkgs[@]}"; then
  log "retrying deps without bash-builtins"
  pkgs_nobash=()
  for p in "${pkgs[@]}"; do
    [[ "$p" == bash-builtins ]] && continue
    pkgs_nobash+=("$p")
  done
  apt-get install -y --no-install-recommends "${pkgs_nobash[@]}"
fi

# Prefer a UTF-8 locale (Meson warns/errors on ANSI_X3.4-1968).
if [[ -f /etc/locale.gen ]] && ! grep -q '^en_US.UTF-8' /etc/locale.gen 2>/dev/null; then
  sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen || true
  locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
fi
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

# Distro Meson can be far too old (Ubuntu xenial 0.29 / stretch 0.37).
# Prefer pip when < 0.56 so repoman's project_source_root() works (API since 0.56).
meson_upgrade_if_old() {
  local ver major=0 minor=0 pyver
  ver="$(meson --version 2>/dev/null | head -1 | tr -cd '0-9.' || true)"
  if [[ "$ver" =~ ^([0-9]+)\.([0-9]+) ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
  fi
  if [[ "$major" -gt 0 ]] || [[ "$minor" -ge 56 ]]; then
    return 0
  fi
  log "Meson ${ver:-unknown} < 0.56; trying pip upgrade"
  apt-get install -y --no-install-recommends python3-pip python3-setuptools python3-wheel 2>/dev/null || true
  if ! command -v pip3 >/dev/null 2>&1; then
    log "pip3 missing; fetching get-pip"
    apt-get install -y --no-install-recommends curl ca-certificates || true
    local getpip
    pyver="$(python3 -c 'import sys; print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo 3)"
    case "$pyver" in
    3.5) getpip="https://bootstrap.pypa.io/pip/3.5/get-pip.py" ;;
    3.6) getpip="https://bootstrap.pypa.io/pip/3.6/get-pip.py" ;;
    *) getpip="https://bootstrap.pypa.io/get-pip.py" ;;
    esac
    curl -fsSL "$getpip" -o /tmp/get-pip.py && python3 /tmp/get-pip.py || true
  fi
  pyver="$(python3 -c 'import sys; print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo 3)"
  if command -v pip3 >/dev/null 2>&1; then
    case "$pyver" in
    3.5)
      # PyPI ninja wheels need Python ≥3.6; keep distro / host-mounted ninja.
      pip3 install --upgrade 'meson==0.54.3' 2>/dev/null \
        || pip3 install --upgrade 'meson==0.47.2' 2>/dev/null \
        || true
      # Do not unlink a working host-mounted ninja (bind-mount may be RO).
      if [[ -e /usr/local/bin/ninja ]] && ! /usr/local/bin/ninja --version >/dev/null 2>&1; then
        rm -f /usr/local/bin/ninja 2>/dev/null || true
      fi
      ;;
    3.6)
      pip3 install --upgrade 'meson==0.61.5' ninja 2>/dev/null \
        || pip3 install --upgrade 'meson==0.54.3' 2>/dev/null \
        || true
      ;;
    *)
      pip3 install --upgrade 'meson==0.61.5' ninja 2>/dev/null \
        || pip3 install --upgrade 'meson>=0.56' ninja 2>/dev/null \
        || true
      ;;
    esac
    hash -r 2>/dev/null || true
    export PATH="/usr/local/bin:${PATH}"
    # Prefer working system ninja if pip ninja is broken.
    if ! ninja --version >/dev/null 2>&1; then
      rm -f /usr/local/bin/ninja 2>/dev/null || true
      if command -v ninja-build >/dev/null 2>&1; then
        ln -sf "$(command -v ninja-build)" /usr/local/bin/ninja
      fi
    fi
  fi
}
meson_upgrade_if_old

# Prefer host-mounted /usr/local/bin/ninja (build-lrm-tools bind-mount) over
# distro ninja-build or a GitHub download (xenial curl TLS often fails).
export PATH="/usr/local/bin:/usr/bin:${PATH}"
_ninja_ver=""
if [[ -x /usr/local/bin/ninja ]]; then
  _ninja_ver="$(/usr/local/bin/ninja --version 2>/dev/null | head -1 || true)"
fi
if [[ -n "$_ninja_ver" ]] && printf '%s\n' "$_ninja_ver" | grep -qE '^1\.(1[0-9]|[6-9])'; then
  log "using mounted ninja: $_ninja_ver"
elif command -v ninja-build >/dev/null 2>&1; then
  if ! command -v ninja >/dev/null 2>&1 || ! ninja --version >/dev/null 2>&1; then
    # Only link if mount point is writable / absent (skip RO bind-mount).
    ln -sf "$(command -v ninja-build)" /usr/local/bin/ninja 2>/dev/null || true
  fi
fi
# Last resort: download a new-enough ninja (may fail on old TLS stacks).
# Skip when a new-enough mounted/system binary already works.
# ninja-linux.zip is amd64-only; aarch64 assets start at newer releases.
# Meson 0.54+ defaults detect_ninja(version='1.7') — xenial's 1.5.1 is too old.
_ninja_ok_ver() { ninja --version 2>/dev/null | grep -qE '^1\.(1[0-9]|[7-9])'; }
if ! _ninja_ok_ver; then
  _ninja_asset=ninja-linux.zip
  case "$(uname -m)" in
  aarch64|arm64) _ninja_asset=ninja-linux-aarch64.zip ;;
  esac
  log "installing ninja ≥1.7 ($_ninja_asset; Meson 0.54+ needs ≥1.7)"
  apt-get install -y --no-install-recommends curl ca-certificates unzip 2>/dev/null || true
  _ninja_ok=0
  # Prefer writing beside a RO mount rather than failing unzip into it.
  _ninja_dest=/usr/local/bin
  if [[ -e /usr/local/bin/ninja ]] && ! touch /usr/local/bin/ninja 2>/dev/null; then
    _ninja_dest=/tmp
  fi
  for _ver in 1.12.1 1.11.1 1.10.2; do
    # 1.10.2 has no aarch64 asset — skip that combo.
    if [[ "$_ninja_asset" == *aarch64* && "$_ver" == 1.10.2 ]]; then
      continue
    fi
    for _url in \
      "https://github.com/ninja-build/ninja/releases/download/v${_ver}/${_ninja_asset}" \
      "https://ghproxy.net/https://github.com/ninja-build/ninja/releases/download/v${_ver}/${_ninja_asset}" \
      "https://ghfast.top/https://github.com/ninja-build/ninja/releases/download/v${_ver}/${_ninja_asset}"
    do
      if curl -fsSL --retry 2 --connect-timeout 20 -o /tmp/ninja-linux.zip "$_url"; then
        unzip -o -q /tmp/ninja-linux.zip -d "$_ninja_dest" || continue
        chmod a+x "$_ninja_dest/ninja"
        if "$_ninja_dest/ninja" --version >/dev/null 2>&1; then
          _ninja_ok=1
          log "installed ninja $("$_ninja_dest/ninja" --version | head -1) from $_url"
          break 2
        fi
        rm -f "$_ninja_dest/ninja"
      fi
    done
  done
  if [[ "$_ninja_ok" -eq 1 ]]; then
    if [[ "$_ninja_dest" != /usr/local/bin ]]; then
      export PATH="${_ninja_dest}:${PATH}"
    fi
  else
    # Drop a broken (wrong-arch) /usr/local/bin/ninja so PATH can see distro ninja.
    if [[ -e /usr/local/bin/ninja ]] && ! /usr/local/bin/ninja --version >/dev/null 2>&1; then
      rm -f /usr/local/bin/ninja 2>/dev/null || true
    fi
    log "warning: could not install ninja ≥1.7; Meson 0.54+ may fail"
  fi
fi
hash -r 2>/dev/null || true
export PATH="/usr/local/bin:/usr/bin:${PATH}"
if ! command -v ninja >/dev/null 2>&1 && command -v ninja-build >/dev/null 2>&1; then
  ln -sf "$(command -v ninja-build)" /usr/local/bin/ninja 2>/dev/null || true
  hash -r 2>/dev/null || true
fi

command -v meson >/dev/null
command -v ninja >/dev/null || command -v ninja-build >/dev/null
log "ready: meson $(meson --version | head -1), ninja $(ninja --version 2>/dev/null || ninja-build --version 2>/dev/null | head -1)"
# Make Meson backends find ninja even if only ninja-build exists.
export NINJA="${NINJA:-$(command -v ninja || command -v ninja-build)}"
