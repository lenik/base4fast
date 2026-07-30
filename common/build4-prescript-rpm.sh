#!/bin/bash
# Runs inside the build4 CentOS/RHEL target before the compile step.
# Installs a toolchain capable of building bas-c + getbar + repoman.
# Yum/dnf sources come from the suite bootstrap repo mounted by build-lrm-tools.sh.

set -euo pipefail

log() { printf 'build4-prescript-rpm: %s\n' "$*" >&2; }
die() { printf 'build4-prescript-rpm: error: %s\n' "$*" >&2; exit 1; }

# Tolerate slow/partial China mirrors: longer timeout, lower minrate, more retries.
# Skip optional filelists metadata (often multi‑MB and the first thing to stall).
configure_pkg_client() {
  if command -v dnf >/dev/null 2>&1; then
    mkdir -p /etc/dnf/dnf.conf.d
    cat >/etc/dnf/dnf.conf.d/99-bootstrap-tolerant.conf <<'EOF'
[main]
timeout=120
minrate=100
retries=15
skip_if_unavailable=True
optional_metadata_types=
EOF
  fi
  if [[ -f /etc/yum.conf ]]; then
    grep -q '^timeout=' /etc/yum.conf 2>/dev/null || echo 'timeout=120' >>/etc/yum.conf
    grep -q '^retries=' /etc/yum.conf 2>/dev/null || echo 'retries=15' >>/etc/yum.conf
    # CentOS 5/6: avoid i386 multilib conflicts with x86_64 base packages.
    if ! grep -q '^exclude=' /etc/yum.conf 2>/dev/null; then
      echo 'exclude=*.i386 *.i686' >>/etc/yum.conf
    fi
    if ! grep -q '^multilib_policy=' /etc/yum.conf 2>/dev/null; then
      echo 'multilib_policy=best' >>/etc/yum.conf
    fi
  fi
}

pkg_install() {
  if command -v dnf >/dev/null 2>&1; then
    # --allowerasing: EL8+ minimal images ship curl-minimal/libcurl-minimal
    dnf -y --allowerasing --setopt=install_weak_deps=False \
      --setopt=timeout=120 --setopt=minrate=100 --setopt=retries=15 \
      --setopt=optional_metadata_types= \
      install "$@"
  elif yum --help 2>&1 | grep -q -- '--setopt'; then
    yum -y --setopt=timeout=120 --setopt=retries=15 install "$@"
  else
    # CentOS 5 yum: no --setopt CLI; exclude 32-bit; skip broken multilib/devel skew.
    yum -y --exclude='*.i386' --exclude='*.i686' --skip-broken install "$@"
  fi
}

# Best-effort install: missing packages must not abort the whole batch.
pkg_install_optional() {
  local p
  for p in "$@"; do
    pkg_install "$p" && continue
    log "optional package not installed: $p"
  done
  return 0
}

ensure_pip() {
  command -v python3 >/dev/null 2>&1 || die "python3 required for pip fallback"

  # Meson and modern get-pip need Python ≥3.5 (not a python2 symlink).
  if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 5) else 1)'; then
    die "python3 is too old for Meson/pip (need ≥3.5; use build-lrm-tools-stub.sh on EL5/EL6)"
  fi

  if python3 -m pip --version >/dev/null 2>&1; then
    return 0
  fi

  log "installing pip for python3"
  pkg_install_optional python3-pip python3-setuptools python3-wheel

  if python3 -m pip --version >/dev/null 2>&1; then
    return 0
  fi

  # ensurepip (stdlib) — often enough on EL8+
  if python3 -m ensurepip --upgrade >/dev/null 2>&1; then
    python3 -m pip --version >/dev/null 2>&1 && return 0
  fi

  # get-pip.py — pick a URL matching the interpreter major.minor
  local py ver url
  ver="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  case "$ver" in
  3.5) url="https://bootstrap.pypa.io/pip/3.5/get-pip.py" ;;
  3.6) url="https://bootstrap.pypa.io/pip/3.6/get-pip.py" ;;
  3.7) url="https://bootstrap.pypa.io/pip/3.7/get-pip.py" ;;
  *)   url="https://bootstrap.pypa.io/get-pip.py" ;;
  esac

  log "bootstrapping pip via $url"
  pkg_install_optional curl ca-certificates
  py="$(mktemp /tmp/get-pip.XXXXXX.py)"
  curl -fsSL --connect-timeout 15 --retry 5 -o "$py" "$url" \
    || die "failed to download get-pip.py"
  python3 "$py" \
    || die "get-pip.py failed"
  rm -f "$py"
  python3 -m pip --version >/dev/null 2>&1 || die "pip still missing after get-pip.py"
}

ensure_meson_ninja() {
  export PATH="/usr/local/bin:${PATH}"
  # Host-mounted ninja from build-lrm-tools (common/build4-bins/ninja).
  if [[ -x /usr/local/bin/ninja ]] && /usr/local/bin/ninja --version >/dev/null 2>&1; then
    log "using mounted ninja: $(/usr/local/bin/ninja --version | head -1)"
  fi

  if command -v meson >/dev/null 2>&1 && { command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1; }; then
    return 0
  fi

  log "installing meson/ninja from distro packages"
  pkg_install_optional meson ninja-build ninja

  if command -v meson >/dev/null 2>&1 && { command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1; }; then
    return 0
  fi

  # Meson still missing — pip. Prefer keeping a working mounted ninja.
  log "meson missing from repos — installing via pip"
  ensure_pip
  python3 -m pip install --upgrade pip setuptools wheel
  # CentOS 7 ships Python 3.6; Meson 0.62+ needs 3.7+. Pin 0.61.5 for <3.7.
  local _need_ninja=1
  if [[ -x /usr/local/bin/ninja ]] && /usr/local/bin/ninja --version >/dev/null 2>&1; then
    _need_ninja=0
  fi
  if python3 -c 'import sys; raise SystemExit(0 if sys.version_info < (3, 7) else 1)'; then
    log "Python < 3.7 detected — pinning meson==0.61.5 (last with 3.6 support)"
    if [[ "$_need_ninja" -eq 1 ]]; then
      python3 -m pip install 'meson==0.61.5' ninja \
        || die "pip install meson ninja failed"
    else
      python3 -m pip install 'meson==0.61.5' \
        || die "pip install meson failed"
    fi
  else
    if [[ "$_need_ninja" -eq 1 ]]; then
      python3 -m pip install 'meson>=0.54' ninja \
        || die "pip install meson ninja failed"
    else
      python3 -m pip install 'meson>=0.54' \
        || die "pip install meson failed"
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
# Core toolchain first (no meson — keep the transaction reliable).
# pkgconfig vs pkgconf-pkg-config differs across EL generations.
core_pkgs=(
  bash
  ca-certificates
  findutils
  which
  gcc
  gcc-c++
  make
  git
  gettext
  libcurl-devel
  openssl-devel
  zlib-devel
  glib2-devel
  libicu-devel
  python3
)

# CentOS 5: install packages one-by-one — one bad devel dep must not abort the rest.
# Also python3 / libicu-devel / git may be missing on stock 5.11 vault.
# CentOS 7: same per-package path — a single 90+ RPM transaction often spins for hours.
if [[ -f /etc/redhat-release ]] && grep -qE 'release (5|7)\b' /etc/redhat-release 2>/dev/null; then
  if grep -q 'release 5' /etc/redhat-release 2>/dev/null; then
    log "CentOS 5 detected — per-package install with --skip-broken"
    for p in bash gcc gcc-c++ make gettext zlib-devel openssl-devel \
             libcurl-devel glib2-devel python python-devel curl; do
      pkg_install_optional "$p"
    done
    pkg_install_optional ca-certificates git libicu-devel python26 python26-devel \
      pkgconfig
  else
    log "CentOS/RHEL 7 detected — per-package install (avoid mega-transaction hang)"
    for p in "${core_pkgs[@]}"; do
      pkg_install_optional "$p"
    done
    pkg_install_optional pkgconfig pkgconf-pkg-config pkgconf
  fi
else
  pkg_install "${core_pkgs[@]}"
  pkg_install_optional pkgconfig pkgconf-pkg-config pkgconf
fi

# Optional bash headers for bash-builtins wrap (need include+builtins dirs).
if [[ ! -d /usr/include/bash/include || ! -d /usr/include/bash/builtins ]]; then
  log "trying packages that provide bash headers"
  pkg_install_optional bash-devel bash-builtins
fi

# Never symlink Python 2.x to python3 — Meson/get-pip need ≥3.5.
# EL5/EL6 should use build-lrm-tools-stub.sh instead of this prescript.
if command -v python3 >/dev/null 2>&1; then
  if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 5) else 1)'; then
    die "python3 too old for Meson (need ≥3.5). On CentOS 5/6 use build-lrm-tools-stub.sh"
  fi
else
  die "python3 ≥3.5 required. On CentOS 5/6 use build-lrm-tools-stub.sh"
fi

ensure_meson_ninja
link_ninja

export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"
# pip --user / local installs
export PATH="/usr/local/bin:${HOME}/.local/bin:${PATH}"

# GCC 4.x on EL7 defaults to C89; bas-c needs C99 for-loop declarations.
if [[ -f /etc/redhat-release ]] && grep -qE 'release 7\b' /etc/redhat-release 2>/dev/null; then
  log "EL7 detected — forcing -std=gnu99 for bas-c"
  export CFLAGS="${CFLAGS:-} -std=gnu99"
  export CXXFLAGS="${CXXFLAGS:-} -std=gnu++11"
fi

command -v meson >/dev/null || die "meson not found after install"
command -v ninja >/dev/null || command -v ninja-build >/dev/null || die "ninja not found after install"
link_ninja

log "ready: meson $(meson --version | head -1), ninja $(ninja --version | head -1)"
