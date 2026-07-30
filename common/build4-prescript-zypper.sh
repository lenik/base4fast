#!/bin/bash
# build4 pre-script for SUSE / openSUSE (zypper) toolchains.
set -euo pipefail

log() { printf 'build4-prescript-zypper: %s\n' "$*" >&2; }
die() { printf 'build4-prescript-zypper: error: %s\n' "$*" >&2; exit 1; }

export PATH="/usr/local/bin:${PATH}"

pkg_install() {
  zypper --non-interactive --gpg-auto-import-keys install --no-recommends "$@" \
    || die "zypper install failed: $*"
}

pkg_install_optional() {
  zypper --non-interactive --gpg-auto-import-keys install --no-recommends "$@" \
    || log "optional package not installed: $*"
}

configure_pkg_client() {
  # Prefer bootstrap / lrm repos already mounted; drop vendor SCC stubs.
  # build4 often bind-mounts /etc/zypp/repos.d read-only — skip moves then.
  if mkdir -p /etc/zypp/repos.d/bak 2>/dev/null; then
    shopt -s nullglob
    for f in /etc/zypp/repos.d/*.repo; do
      case "$(basename "$f")" in
      lrm.repo|lrm-bootstrap.repo) continue ;;
      esac
      mv -f "$f" /etc/zypp/repos.d/bak/ 2>/dev/null || true
    done
    shopt -u nullglob
  else
    log "repos.d not writable (build4 mount) — using mounted bootstrap as-is"
  fi
  zypper --non-interactive --gpg-auto-import-keys refresh || true
}

ensure_pip() {
  if python3 -m pip --version >/dev/null 2>&1; then
    return 0
  fi
  pkg_install_optional python3-pip python3-setuptools python3-wheel
  if python3 -m pip --version >/dev/null 2>&1; then
    return 0
  fi
  local pyver url py
  pyver="$(python3 -c 'import sys; print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo 3)"
  case "$pyver" in
  3.5) url="https://bootstrap.pypa.io/pip/3.5/get-pip.py" ;;
  3.6) url="https://bootstrap.pypa.io/pip/3.6/get-pip.py" ;;
  3.7) url="https://bootstrap.pypa.io/pip/3.7/get-pip.py" ;;
  *)   url="https://bootstrap.pypa.io/get-pip.py" ;;
  esac
  py="$(mktemp)"
  curl -fsSL "$url" -o "$py" || die "download get-pip.py failed"
  python3 "$py" || die "get-pip.py failed"
  rm -f "$py"
}

ensure_meson_ninja() {
  export PATH="/usr/local/bin:${PATH}"
  if [[ -x /usr/local/bin/ninja ]] && /usr/local/bin/ninja --version >/dev/null 2>&1; then
    log "using mounted ninja: $(/usr/local/bin/ninja --version | head -1)"
  fi

  if command -v meson >/dev/null 2>&1 && { command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1; }; then
    return 0
  fi

  log "installing meson/ninja from distro packages"
  pkg_install_optional meson ninja
  if command -v meson >/dev/null 2>&1 && { command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1; }; then
    return 0
  fi

  log "meson missing from repos — installing via pip"
  ensure_pip
  python3 -m pip install --upgrade pip setuptools wheel || true
  local _need_ninja=1
  if [[ -x /usr/local/bin/ninja ]] && /usr/local/bin/ninja --version >/dev/null 2>&1; then
    _need_ninja=0
  fi
  if python3 -c 'import sys; raise SystemExit(0 if sys.version_info < (3, 7) else 1)'; then
    log "Python < 3.7 detected — pinning meson==0.61.5"
    if [[ "$_need_ninja" -eq 1 ]]; then
      python3 -m pip install 'meson==0.61.5' ninja || die "pip install meson ninja failed"
    else
      python3 -m pip install 'meson==0.61.5' || die "pip install meson failed"
    fi
  else
    if [[ "$_need_ninja" -eq 1 ]]; then
      python3 -m pip install 'meson>=0.54' ninja || die "pip install meson ninja failed"
    else
      python3 -m pip install 'meson>=0.54' || die "pip install meson failed"
    fi
  fi
}

link_ninja() {
  if ! command -v ninja >/dev/null 2>&1 && command -v ninja-build >/dev/null 2>&1; then
    ln -sf "$(command -v ninja-build)" /usr/local/bin/ninja 2>/dev/null || true
  fi
}

configure_pkg_client

log "installing build dependencies"
pkg_install \
  bash ca-certificates gcc gcc-c++ make git gettext-tools \
  libcurl-devel libopenssl-devel zlib-devel \
  glib2-devel libicu-devel python3 \
  || pkg_install bash gcc gcc-c++ make git python3

pkg_install_optional pkg-config pkgconfig
pkg_install_optional bash-devel

if ! command -v python3 >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
  ln -sf "$(command -v python)" /usr/local/bin/python3 2>/dev/null || true
fi

ensure_meson_ninja
link_ninja

export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"
export PATH="/usr/local/bin:${HOME}/.local/bin:${PATH}"

command -v meson >/dev/null || die "meson not found after install"
command -v ninja >/dev/null || command -v ninja-build >/dev/null || die "ninja not found after install"
link_ninja

log "ready: meson $(meson --version | head -1), ninja $(ninja --version | head -1)"
