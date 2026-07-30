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
# Prefer a real ninja binary Meson can version-detect.
if command -v ninja >/dev/null 2>&1; then
  export NINJA="$(command -v ninja)"
elif command -v ninja-build >/dev/null 2>&1; then
  ln -sf "$(command -v ninja-build)" /usr/local/bin/ninja
  export NINJA=/usr/local/bin/ninja
fi

PREFIX=/out
BUILD=/tmp/lrm-build

# GCC 4.x on EL7 defaults to C89; bas-c needs C99 for-loop declarations.
if [[ -f /etc/redhat-release ]] && grep -qE 'release 7\b' /etc/redhat-release 2>/dev/null; then
  log "EL7 detected — forcing CFLAGS=-std=gnu99"
  export CFLAGS="${CFLAGS:+$CFLAGS }-std=gnu99"
  export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-std=gnu++11"
fi
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
# Also stage getbar so we can patch Meson < 0.50 gettext (project_source_root).
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
# Wrap meson.build requires absolute /usr/include/bash{,/include,/builtins}.
# Host subprojects may still ship bash-builtins/bash-headers; drop them when
# headers are incomplete so Meson does not configure a doomed subproject.
have_bash_inc=0
if [[ -d /usr/include/bash/include && -d /usr/include/bash/builtins ]]; then
  have_bash_inc=1
fi
if [[ "$have_bash_inc" -eq 0 ]]; then
  for name in bash-builtins bash-headers; do
    if [[ -e "$BUILD/bas-c/subprojects/$name" ]]; then
      log "removing subproject $name (incomplete /usr/include/bash headers)"
      rm -rf "$BUILD/bas-c/subprojects/$name"
    fi
  done
  log "skipping bash-builtins wrap (need /usr/include/bash/{include,builtins})"
  # bas-c falls back to dependency(..., required: true) when the subproject
  # is absent — soften that and skip libbas-bash (needs those headers).
  log "patching bas-c: optional bash-builtins, skip libbas-bash"
  python3 - "$BUILD/bas-c/meson.build" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace(
    "bash_builtins_dep = dependency('bash-builtins', required: true)",
    "bash_builtins_dep = dependency('bash-builtins', required: false)",
)
text2, n = re.subn(
    r"\n# Bash loadable: libbas-bash \(bb-util\)\nbas_bash = shared_library\(.*?\n\)\n",
    "\n# libbas-bash skipped by build4-inside (no bash headers)\n",
    text,
    count=1,
    flags=re.S,
)
open(path, "w", encoding="utf-8").write(text2 if n else text)
PY
elif [[ ! -f "$BUILD/bas-c/subprojects/bash-builtins/meson.build" ]]; then
  log "installing bash-builtins wrap"
  cp -a /src/wraps/bash-builtins "$BUILD/bas-c/subprojects/bash-builtins"
fi

# bas-c unit-test discovery needs the `includes` CLI at meson configure time
# (Meson ≥0.47 run_command looks up the program even with check:false).
# Stretch Meson 0.37 uses a shell fallback and does not need the binary.
if [[ -f /src/includes/meson.build ]] && { [[ "$meson_major" -gt 0 ]] || [[ "$meson_minor" -ge 47 ]]; }; then
  log "building includes (for bas-c tests)"
  mkdir -p "$BUILD/includes"
  cp -a /src/includes/. "$BUILD/includes/"
  # Drop unit tests: `args: [exe, ...]` needs newer Meson than Stretch 0.37.
  if grep -q '^# Tests' "$BUILD/includes/meson.build"; then
    sed -i '/^# Tests/,$d' "$BUILD/includes/meson.build"
  fi
  meson_configure "$BUILD/includes-build" "$BUILD/includes" --prefix="$PREFIX" --libdir=lib
  meson_build "$BUILD/includes-build"
  meson_install_to "$BUILD/includes-build"
  export PATH="$PREFIX/bin:${PATH}"
  command -v includes >/dev/null || die "includes not on PATH after install"
elif [[ -f /src/includes/meson.build ]]; then
  log "Meson < 0.47: skipping includes (bas-c uses shell fallback)"
else
  log "warning: /src/includes missing; bas-c configure may fail on Meson ≥0.47"
fi

# SUSE ICU: ELF SONAME is libicuuc.so.N but file is often libicuuc.so.suseN.1
if [[ -d /usr/lib64 ]]; then
  shopt -s nullglob
  for real in /usr/lib64/libicu*.so.suse*; do
    base=$(basename "$real")
    if [[ "$base" =~ ^(libicu[a-z]+)\.so\.suse([0-9]+) ]]; then
      soname="${BASH_REMATCH[1]}.so.${BASH_REMATCH[2]}"
      if [[ ! -e "/usr/lib64/$soname" ]]; then
        log "ICU soname symlink: /usr/lib64/$soname -> $base"
        ln -sfn "$base" "/usr/lib64/$soname"
      fi
    fi
  done
  shopt -u nullglob
fi

log "building bas-c"
# Stretch Meson 0.37 only accepts warning_level 1|2|3 (not 0).
# Do not pass -Ddefault_library=both: on Meson ≥0.46 `library()` already
# emits both shared+static under that option, which then clashes with our
# explicit static_library('bas-c').
bas_c_opts=(--prefix="$PREFIX" --libdir=lib)
# EL7 GCC 4.8 defaults to C89; force C99 for bas-c for-loop decls.
if [[ -f /etc/redhat-release ]] && grep -qE "release 7\b" /etc/redhat-release 2>/dev/null; then
  log "EL7: meson -Dc_args=-std=gnu99"
  bas_c_opts+=(-Dc_args=-std=gnu99)
fi
if [[ "$meson_major" -eq 0 && "$meson_minor" -lt 40 ]]; then
  sed -i "s/warning_level=0/warning_level=1/g" "$BUILD/bas-c/meson.build" || true
  bas_c_opts+=(-Dwarning_level=1)
fi
# Multiline run_target('posync') breaks the ninja backend on many Meson versions.
if grep -q "run_target(" "$BUILD/bas-c/meson.build" && grep -q "'posync'" "$BUILD/bas-c/meson.build"; then
  log "disabling bas-c posync run_target (multiline → ninja)"
  python3 - "$BUILD/bas-c/meson.build" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text2, n = re.subn(
    r"\nif meson\.version\(\)\.version_compare\('>=0\.50\.0'\)\n    run_target\(\n        'posync',.*?\n    \)\nendif\n",
    "\n# posync disabled by build4-inside (multiline run_target breaks ninja)\n",
    text,
    count=1,
    flags=re.S,
)
if n:
    open(path, "w", encoding="utf-8").write(text2)
PY
fi
# bas-c po/ uses project_source_root() (Meson ≥0.56); upstream gate is wrongly ≥0.50.
if [[ "$meson_major" -eq 0 && "$meson_minor" -lt 56 ]]; then
  log "Meson < 0.56: disabling bas-c po/ (project_source_root unavailable)"
  sed -i "s/have_po and meson.version().version_compare('>=0.50.0')/false  # disabled: need Meson >= 0.56/" \
    "$BUILD/bas-c/meson.build" || true
fi
meson_configure "$BUILD/bas-c-build" "$BUILD/bas-c" "${bas_c_opts[@]}"
meson_build "$BUILD/bas-c-build"
meson_install_to "$BUILD/bas-c-build"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"

log "preparing getbar sources"
mkdir -p "$BUILD/getbar"
cp -a /src/getbar/. "$BUILD/getbar/"
# po/meson.build uses meson.project_source_root() (Meson ≥0.56).
if [[ "$meson_major" -eq 0 && "$meson_minor" -lt 56 ]]; then
  log "Meson < 0.56: disabling getbar po/ (project_source_root unavailable)"
  if [[ -f "$BUILD/getbar/meson.build" ]]; then
    sed -i "s/subdir('po')/# subdir('po')  # disabled: Meson < 0.56/" "$BUILD/getbar/meson.build" || true
  fi
fi
# Convenience run_targets embed multiline bash; ninja backend rejects newlines.
if grep -q "run_target(" "$BUILD/getbar/meson.build"; then
  log "stripping getbar multiline run_targets (look/install-symlinks/...)"
  python3 - "$BUILD/getbar/meson.build" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text2, n = re.subn(
    r"\nrun_target\(\n    '(?:look|install-symlinks|uninstall-symlinks)',.*?\n\)\n",
    "\n",
    text,
    flags=re.S,
)
if n:
    open(path, "w", encoding="utf-8").write(text2)
PY
fi
# Meson < 0.49 path: getbar hardcodes prefix=/usr and ignores --prefix.
# Rewrite the else-branch install layout to honor get_option('prefix').
if [[ "$meson_major" -eq 0 && "$meson_minor" -lt 49 ]]; then
  log "Meson < 0.49: patching getbar install dirs to honor --prefix"
  python3 - "$BUILD/getbar/meson.build" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
old = """else
    prefix = '/usr'
    bindir = '/usr/bin'
    datadir = '/usr/share'
    localedir = '/usr/share/locale'
    mandir = '/usr/share/man'
    pkgdatadir = join_paths(datadir, meson.project_name())
    pkgdocdir = join_paths(datadir, 'doc', meson.project_name())
    bash_completions_dir = join_paths(datadir, 'bash-completion', 'completions')
    pkgdoc_images_dir = join_paths(pkgdocdir, 'images')
    man1_dir = join_paths(mandir, 'man1')
endif"""
new = """else
    prefix = get_option('prefix')
    bindir = join_paths(prefix, 'bin')
    datadir = join_paths(prefix, 'share')
    localedir = join_paths(prefix, 'share', 'locale')
    mandir = join_paths(prefix, 'share', 'man')
    pkgdatadir = join_paths(datadir, meson.project_name())
    pkgdocdir = join_paths(datadir, 'doc', meson.project_name())
    bash_completions_dir = join_paths(datadir, 'bash-completion', 'completions')
    pkgdoc_images_dir = join_paths(pkgdocdir, 'images')
    man1_dir = join_paths(mandir, 'man1')
endif"""
if old not in text:
    raise SystemExit("getbar prefix else-branch not found for patch")
open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
fi

log "building getbar"
meson_configure "$BUILD/getbar-build" "$BUILD/getbar" \
  --prefix="$PREFIX" \
  --libdir=lib \
  -Dreadme-pdf=false
meson_build "$BUILD/getbar-build"
meson_install_to "$BUILD/getbar-build"
# Safety net if a suite still installs outside PREFIX.
if [[ ! -x "$PREFIX/bin/getbar" ]]; then
  for cand in /usr/bin/getbar /usr/local/bin/getbar; do
    if [[ -x "$cand" ]]; then
      log "copying getbar from $cand into $PREFIX/bin"
      mkdir -p "$PREFIX/bin"
      cp -a "$cand" "$PREFIX/bin/getbar"
      break
    fi
  done
fi

log "building repoman (lrm)"
mkdir -p "$BUILD/repoman"
cp -a /src/repoman/. "$BUILD/repoman/"
# project_source_root() is Meson ≥0.56; upstream gate wrongly uses ≥0.50.
if [[ "$meson_major" -eq 0 && "$meson_minor" -lt 56 ]]; then
  log "Meson < 0.56: patching repoman project_source_root gate"
  sed -i "s/version_compare('>=0.50.0')/version_compare('>=0.56.0')/g" \
    "$BUILD/repoman/meson.build" || true
  if [[ -f "$BUILD/repoman/po/meson.build" ]]; then
    # Skip po/ if it still calls project_source_root unconditionally.
    if grep -q 'project_source_root' "$BUILD/repoman/po/meson.build"; then
      sed -i "s/subdir('po')/# subdir('po')  # disabled: Meson < 0.56/" \
        "$BUILD/repoman/meson.build" || true
    fi
  fi
fi
meson_configure "$BUILD/repoman-build" "$BUILD/repoman" \
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
