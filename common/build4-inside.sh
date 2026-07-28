#!/bin/bash
# Compile bas-c, getbar, and repoman inside the build4 target container.
# Installs into /out (bind-mounted host artifact dir).
#
# Compatible with both modern Meson (`setup`/`compile`) and Stretch-era 0.37.

set -euo pipefail

log() { printf 'build4-inside: %s\n' "$*" >&2; }
die() { printf 'build4-inside: error: %s\n' "$*" >&2; exit 1; }

export PATH="/usr/local/bin:${PATH}"
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

PREFIX=/out
BUILD=/tmp/lrm-build
rm -rf "$BUILD"
mkdir -p "$BUILD" "$PREFIX"

[[ -f /src/getbar/meson.build ]] || die "missing /src/getbar"
[[ -f /src/repoman/meson.build ]] || die "missing /src/repoman"
[[ -f /src/bas-c-src/meson.build ]] || die "missing /src/bas-c-src"

# Detect Meson CLI flavour by version (do NOT probe `meson setup --help` on
# 0.37 — it treats "setup" as a source directory and exits 0).
MESON_VER="$(meson --version 2>/dev/null | head -1 | tr -cd '0-9.' || true)"
log "meson ${MESON_VER:-unknown}"

meson_major=0
meson_minor=0
if [[ "$MESON_VER" =~ ^([0-9]+)\.([0-9]+) ]]; then
  meson_major="${BASH_REMATCH[1]}"
  meson_minor="${BASH_REMATCH[2]}"
fi

# `meson setup` became the preferred interface ~0.42; `compile` landed in 0.54.
meson_has_setup=0
meson_has_compile=0
if [[ "$meson_major" -gt 0 ]] || [[ "$meson_major" -eq 0 && "$meson_minor" -ge 42 ]]; then
  meson_has_setup=1
fi
if [[ "$meson_major" -gt 0 ]] || [[ "$meson_major" -eq 0 && "$meson_minor" -ge 54 ]]; then
  meson_has_compile=1
fi

meson_configure() {
  local builddir="$1" srcdir="$2"
  shift 2
  if [[ "$meson_has_setup" -eq 1 ]]; then
    meson setup "$builddir" "$srcdir" "$@"
  else
    # Meson ≤ ~0.41: meson [opts] srcdir builddir
    meson "$@" "$srcdir" "$builddir"
  fi
}

meson_build() {
  local builddir="$1"
  if [[ "$meson_has_compile" -eq 1 ]]; then
    meson compile -C "$builddir"
  else
    ninja -C "$builddir"
  fi
}

meson_install_to() {
  local builddir="$1"
  if [[ "$meson_has_compile" -eq 1 ]] && meson install --help >/dev/null 2>&1; then
    meson install -C "$builddir"
  else
    DESTDIR= ninja -C "$builddir" install
  fi
}

# Writable bas-c tree: real subprojects from host + bash-builtins wrap if missing.
log "preparing bas-c sources"
mkdir -p "$BUILD/bas-c"
cp -a /src/bas-c-src/. "$BUILD/bas-c/"
rm -rf "$BUILD/bas-c/subprojects"
mkdir -p "$BUILD/bas-c/subprojects"
if [[ -d /src/bas-c-subprojects ]]; then
  for d in /src/bas-c-subprojects/*; do
    [[ -e "$d" ]] || continue
    name="$(basename "$d")"
    # Skip broken / empty entries (e.g. inaccessible bash-builtins).
    if [[ -d "$d" && -f "$d/meson.build" ]]; then
      cp -a "$d" "$BUILD/bas-c/subprojects/$name"
    else
      log "skipping subproject $name (missing or unreadable)"
    fi
  done
fi
if [[ ! -f "$BUILD/bas-c/subprojects/bash-builtins/meson.build" ]]; then
  log "installing bash-builtins wrap"
  cp -a /src/wraps/bash-builtins "$BUILD/bas-c/subprojects/bash-builtins"
fi

log "building bas-c"
# Stretch Meson 0.37 only accepts warning_level 1|2|3 (not 0).
# Do not pass -Ddefault_library=both: on Meson ≥0.46 `library()` already
# emits both shared+static under that option, which then clashes with our
# explicit static_library('bas-c').
bas_c_opts=(--prefix="$PREFIX" --libdir=lib)
if [[ "$meson_major" -eq 0 && "$meson_minor" -lt 40 ]]; then
  sed -i "s/warning_level=0/warning_level=1/g" "$BUILD/bas-c/meson.build" || true
  bas_c_opts+=(-Dwarning_level=1)
fi
meson_configure "$BUILD/bas-c-build" "$BUILD/bas-c" "${bas_c_opts[@]}"
meson_build "$BUILD/bas-c-build"
meson_install_to "$BUILD/bas-c-build"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"

log "building getbar"
meson_configure "$BUILD/getbar-build" /src/getbar \
  --prefix="$PREFIX" \
  --libdir=lib \
  -Dreadme-pdf=false
meson_build "$BUILD/getbar-build"
meson_install_to "$BUILD/getbar-build"

log "building repoman (lrm)"
meson_configure "$BUILD/repoman-build" /src/repoman \
  --prefix="$PREFIX" \
  --libdir=lib
meson_build "$BUILD/repoman-build"
meson_install_to "$BUILD/repoman-build"

mkdir -p "$PREFIX/bin" "$PREFIX/share"
# configure_file without install_mode may leave scripts non-executable on Meson 0.37.
chmod a+x "$PREFIX/bin/getbar" "$PREFIX/bin/lrm" "$PREFIX/bin/drm" 2>/dev/null || true
[[ -x "$PREFIX/bin/getbar" ]] || die "getbar not installed to $PREFIX/bin"
[[ -x "$PREFIX/bin/lrm" ]] || die "lrm not installed to $PREFIX/bin"

if [[ ! -f "$PREFIX/share/repoman/common.sh" ]]; then
  found="$(find "$PREFIX" -name common.sh -path '*/repoman/*' | head -1 || true)"
  [[ -n "$found" ]] || die "repoman common.sh not found under $PREFIX"
  mkdir -p "$PREFIX/share/repoman"
  cp -a "$(dirname "$found")/." "$PREFIX/share/repoman/"
fi

log "artifacts:"
find "$PREFIX" -type f | head -50 || true
