#!/bin/bash
# build4 pre-script for SUSE / openSUSE (zypper) toolchains.
set -euo pipefail

log() { printf 'build4-prescript-zypper: %s\n' "$*" >&2; }
die() { printf 'build4-prescript-zypper: error: %s\n' "$*" >&2; exit 1; }

# PyPI: prefer direct HTTPS (privoxy often 503s pythonhosted).
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy 2>/dev/null || true
export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-300}"

export PATH="/usr/local/bin:${PATH}"

pkg_install() {
  local attempt=1
  local max=4
  while true; do
    if zypper --non-interactive --gpg-auto-import-keys install --no-recommends "$@"; then
      return 0
    fi
    if [[ "$attempt" -ge "$max" ]]; then
      die "zypper install failed after ${max} attempts: $*"
    fi
    log "zypper install failed (attempt $attempt/$max) — retrying in $((attempt * 5))s"
    sleep $((attempt * 5))
    attempt=$((attempt + 1))
  done
}


pkg_install_optional() {
  zypper --non-interactive --gpg-auto-import-keys install --no-recommends "$@" \
    || log "optional package not installed: $*"
}

configure_pkg_client() {
  # Prefer bootstrap / lrm repos already mounted; drop vendor SCC stubs.
  # build4 often bind-mounts /etc/zypp/repos.d read-only — skip moves then.
  # When no lrm-bootstrap is mounted (e.g. BCI 16.x), keep image SLE_BCI repos.
  if [[ ! -f /etc/zypp/repos.d/lrm-bootstrap.repo ]]; then
    log "no lrm-bootstrap.repo — keeping image zypper repos"
  elif mkdir -p /etc/zypp/repos.d/bak 2>/dev/null; then
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
  # allowDowngrade is provided by mounted scripts/zypp-conf/zypp.conf when present.
  # Do not append here: build4 often bind-mounts zypp.conf read-only.
  if [[ -f /etc/zypp/zypp.conf ]]; then
    if grep -q '^solver.allowDowngrade' /etc/zypp/zypp.conf 2>/dev/null; then
      log "zypp.conf has solver.allowDowngrade"
    else
      log "zypp.conf present without allowDowngrade (ok if not needed)"
    fi
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
  py="$(mktemp)"
  if [[ -f /src/build4-bootstrap/get-pip.py ]]; then
    log "using mounted get-pip.py"
    cp -f /src/build4-bootstrap/get-pip.py "$py"
  else
    case "$pyver" in
    3.4) url="https://bootstrap.pypa.io/pip/3.4/get-pip.py" ;;
    3.5) url="https://bootstrap.pypa.io/pip/3.5/get-pip.py" ;;
    3.6) url="https://bootstrap.pypa.io/pip/3.6/get-pip.py" ;;
    3.7) url="https://bootstrap.pypa.io/pip/3.7/get-pip.py" ;;
    *)   url="https://bootstrap.pypa.io/get-pip.py" ;;
    esac
    curl -fsSL "$url" -o "$py" || die "download get-pip.py failed"
  fi
  python3 "$py" || die "get-pip.py failed"
  rm -f "$py"
}

# openSUSE/SLES ICU uses filenames like libicuuc.so.suse65.1 while the ELF
# SONAME is libicuuc.so.65 — Meson links the SONAME path and fails without it.
ensure_suse_icu_sonames() {
  local libdir=/usr/lib64
  [[ -d "$libdir" ]] || libdir=/usr/lib
  shopt -s nullglob
  local real base soname
  for real in "$libdir"/libicu*.so.suse*; do
    base="$(basename "$real")"
    if [[ "$base" =~ ^(libicu[a-z]+)\.so\.suse([0-9]+) ]]; then
      soname="${BASH_REMATCH[1]}.so.${BASH_REMATCH[2]}"
      if [[ ! -e "$libdir/$soname" ]]; then
        log "ICU soname symlink: $libdir/$soname -> $base"
        ln -sfn "$base" "$libdir/$soname"
      fi
    fi
  done
  shopt -u nullglob
}


ensure_meson_ninja() {
  export PATH="/usr/local/bin:${PATH}"
  if [[ -x /usr/local/bin/ninja ]] && /usr/local/bin/ninja --version >/dev/null 2>&1; then
    log "using mounted ninja: $(/usr/local/bin/ninja --version | head -1)"
  fi

  # Leap 42.1 / old SLES ship Meson that lacks --version / setup; force pip.
  local _force_pip=0
  if [[ -f /etc/os-release ]] && grep -qE 'VERSION(_ID)?="42\.1"' /etc/os-release 2>/dev/null; then
    _force_pip=1
    log "Leap 42.1 detected — forcing meson via pip (distro Meson too old)"
  elif command -v meson >/dev/null 2>&1; then
    if ! meson --version >/dev/null 2>&1; then
      _force_pip=1
      log "distro meson lacks --version — forcing pip"
    fi
  fi

  if [[ "$_force_pip" -eq 0 ]] \
    && command -v meson >/dev/null 2>&1 \
    && { command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1; }; then
    return 0
  fi

  if [[ "$_force_pip" -eq 0 ]]; then
    log "installing meson/ninja from distro packages"
    pkg_install_optional meson ninja
    if command -v meson >/dev/null 2>&1 && { command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1; }; then
      return 0
    fi
  fi

  log "meson missing/too-old — installing via pip"
  ensure_pip
  if [[ -z "${PIP_INDEX_URL:-}" ]]; then
    export PIP_INDEX_URL="https://mirrors.aliyun.com/pypi/simple/"
    export PIP_TRUSTED_HOST="mirrors.aliyun.com"
  fi
  python3 -m pip install --upgrade pip setuptools wheel || true
  pip_install() {
    local wheels=/src/build4-wheels
    local -a args=(--default-timeout="${PIP_DEFAULT_TIMEOUT:-300}" --retries=10)
    if [[ -d "$wheels" ]] && compgen -G "$wheels"/*.whl >/dev/null 2>&1; then
      log "pip install from mounted wheels ($wheels)"
      python3 -m pip install "${args[@]}" --no-index --find-links="$wheels" "$@" \
        || python3 -m pip install "${args[@]}" "$@"
    else
      python3 -m pip install "${args[@]}" "$@"
    fi
  }
  local _need_ninja=1
  if [[ -x /usr/local/bin/ninja ]] && /usr/local/bin/ninja --version >/dev/null 2>&1; then
    _need_ninja=0
  fi
  if python3 -c 'import sys; raise SystemExit(0 if sys.version_info < (3, 7) else 1)'; then
    log "Python < 3.7 detected — pinning meson==0.61.5"
    if [[ "$_need_ninja" -eq 1 ]]; then
      pip_install 'meson==0.61.5' ninja || die "pip install meson ninja failed"
    else
      pip_install 'meson==0.61.5' || die "pip install meson failed"
    fi
  else
    if [[ "$_need_ninja" -eq 1 ]]; then
      pip_install 'meson>=0.54' ninja || die "pip install meson ninja failed"
    else
      pip_install 'meson>=0.54' || die "pip install meson failed"
    fi
  fi
  # Prefer pip meson over ancient distro /usr/bin/meson
  export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
  hash -r 2>/dev/null || true
  if ! meson --version >/dev/null 2>&1; then
    die "pip meson still not usable after install"
  fi
  log "pip meson ok: $(meson --version | head -1)"
}

link_ninja() {
  if ! command -v ninja >/dev/null 2>&1 && command -v ninja-build >/dev/null 2>&1; then
    ln -sf "$(command -v ninja-build)" /usr/local/bin/ninja 2>/dev/null || true
  fi
}

configure_pkg_client

log "installing build dependencies"
# Leap 42.1 / archive image ships libpcre1-8.39 but OSS only has 8.33 + matching
# pcre-devel. Old zypper --non-interactive will not auto-downgrade; force via rpm.
if [[ -f /etc/os-release ]] && grep -q 'VERSION="42.1"' /etc/os-release 2>/dev/null; then
  if rpm -q libpcre1 >/dev/null 2>&1 && ! rpm -q libpcre1 | grep -q '8.33'; then
    log "Leap 42.1: downgrading libpcre* to 8.33 for glib2-devel"
    rpms=/src/build4-rpms
    if [[ ! -d "$rpms" ]]; then
      die "missing mounted /src/build4-rpms (host scripts/build4-bins/rpms)"
    fi
    rpm -Uvh --oldpackage \
      "$rpms"/libpcre1-8.33-3.5.x86_64.rpm \
      "$rpms"/libpcre16-0-8.33-3.5.x86_64.rpm \
      "$rpms"/libpcrecpp0-8.33-3.5.x86_64.rpm \
      "$rpms"/libpcreposix0-8.33-3.5.x86_64.rpm \
      || die "rpm --oldpackage libpcre* failed"
  fi
fi

pkg_install \
  bash ca-certificates gcc gcc-c++ make git gettext-tools \
  libcurl-devel libopenssl-devel zlib-devel \
  glib2-devel libicu-devel python3 \
  || pkg_install bash gcc gcc-c++ make git python3

pkg_install_optional pkg-config pkgconfig
# Leap 42.1: pcre-devel after pkg-config / libstdc++-devel available
if [[ -f /src/build4-rpms/pcre-devel-8.33-3.5.x86_64.rpm ]]; then
  rpm -Uvh --oldpackage /src/build4-rpms/pcre-devel-8.33-3.5.x86_64.rpm \
    || pkg_install_optional pcre-devel
else
  pkg_install_optional pcre-devel pcre2-devel
fi
pkg_install_optional bash-devel
ensure_suse_icu_sonames

if ! command -v python3 >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
  ln -sf "$(command -v python)" /usr/local/bin/python3 2>/dev/null || true
fi

ensure_meson_ninja
link_ninja
ensure_suse_icu_sonames

export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"
export PATH="/usr/local/bin:${HOME}/.local/bin:${PATH}"

command -v meson >/dev/null || die "meson not found after install"
command -v ninja >/dev/null || command -v ninja-build >/dev/null || die "ninja not found after install"
link_ninja

log "ready: meson $(meson --version 2>/dev/null | head -1 || echo unknown), ninja $(ninja --version 2>/dev/null | head -1 || echo unknown)"
