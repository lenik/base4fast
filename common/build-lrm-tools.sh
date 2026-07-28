#!/bin/bash
# Build getbar + repoman (lrm) for a Debian suite using build4.
# Outputs a relocatable tree under <suite>/vendor/ suitable for COPY into the image.
#
# Usage: build-lrm-tools.sh SUITE
#   SUITE  stretch|buster|bullseye|bookworm|trixie
#
# Sources are git-cloned into common/deps/ (override with *_SRC or *_GIT).
#
# Environment (optional):
#   BUILD4          path to build4 (default: /home/cursor/dockers/build4/build4)
#   DEPS_DIR        clone directory (default: common/deps)
#   GETBAR_GIT      getbar repo URL
#   REPOMAN_GIT     repoman repo URL
#   BAS_C_GIT       bas-c repo URL
#   GETBAR_SRC      use existing tree instead of cloning
#   REPOMAN_SRC     use existing tree instead of cloning
#   BAS_C_SRC       use existing tree instead of cloning
#   BAS_SUBPROJECTS bas-c subprojects tree (default: /home/lenik/tasks/udisk/subprojects)
#   KEEP_BUILD4     if 1, pass -k to build4

set -euo pipefail

SUITE="${1:?usage: build-lrm-tools.sh SUITE}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/common"
SUITE_DIR="$ROOT/$SUITE"
VENDOR="$SUITE_DIR/vendor"
BUILD4="${BUILD4:-/home/cursor/dockers/build4/build4}"
DEPS_DIR="${DEPS_DIR:-$COMMON/deps}"
GETBAR_GIT="${GETBAR_GIT:-https://github.com/lenik/getbar.git}"
REPOMAN_GIT="${REPOMAN_GIT:-https://github.com/lenik/repoman.git}"
BAS_C_GIT="${BAS_C_GIT:-https://github.com/lenik/bas-c.git}"
# bas-c ships a broken subprojects → ../subprojects/ symlink; point at the real tree.
BAS_SUBPROJECTS="${BAS_SUBPROJECTS:-/home/lenik/tasks/udisk/subprojects}"
TARGET="debian:${SUITE}"
WORK="$COMMON/.build4-work/${SUITE}"

log() { printf 'build-lrm-tools: %s\n' "$*" >&2; }
die() { printf 'build-lrm-tools: error: %s\n' "$*" >&2; exit 1; }

# After cloning bas-c, replace broken subprojects symlink with BAS_SUBPROJECTS.
fix_bas_c_subprojects() {
    local bas="$1"
    [[ -d "$BAS_SUBPROJECTS" ]] || die "bas-c subprojects missing: $BAS_SUBPROJECTS"
    if [[ -L "$bas/subprojects" ]] || [[ ! -e "$bas/subprojects" ]]; then
        rm -f "$bas/subprojects"
        ln -sfn "$BAS_SUBPROJECTS" "$bas/subprojects"
    elif [[ -d "$bas/subprojects" ]]; then
        log "bas-c already has a subprojects directory; leaving as-is"
        return 0
    fi
    log "bas-c subprojects → $(readlink -f "$bas/subprojects")"
}

# Resolve source tree: use explicit SRC if set, otherwise clone into DEPS_DIR/<name>.
ensure_git_src() {
    local name="$1" url="$2" dest="${3:-}"

    if [[ -n "$dest" ]]; then
        [[ -f "$dest/meson.build" ]] || die "$name SRC missing meson.build: $dest"
        log "using existing $name at $dest"
        printf '%s\n' "$dest"
        return 0
    fi

    local dir="$DEPS_DIR/$name"
    mkdir -p "$DEPS_DIR"

    if [[ -d "$dir/.git" ]]; then
        log "updating $name in $dir"
        git -C "$dir" fetch --depth 1 origin
        local ref
        ref="$(git -C "$dir" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || true)"
        if [[ -n "$ref" ]]; then
            git -C "$dir" checkout -q -B "$(basename "$ref")" "$ref"
        elif git -C "$dir" rev-parse -q --verify origin/master >/dev/null; then
            git -C "$dir" checkout -q -B master origin/master
        elif git -C "$dir" rev-parse -q --verify origin/main >/dev/null; then
            git -C "$dir" checkout -q -B main origin/main
        else
            git -C "$dir" pull --ff-only || true
        fi
    else
        log "cloning $url → $dir"
        rm -rf "$dir"
        git clone --depth 1 "$url" "$dir"
    fi
    [[ -f "$dir/meson.build" ]] || die "$name missing meson.build after clone: $dir"
    printf '%s\n' "$dir"
}

[[ -x "$BUILD4" ]] || die "build4 not executable: $BUILD4"
[[ -d "$SUITE_DIR" ]] || die "unknown suite dir: $SUITE_DIR"

GETBAR_SRC="$(ensure_git_src getbar "$GETBAR_GIT" "${GETBAR_SRC:-}")"
REPOMAN_SRC="$(ensure_git_src repoman "$REPOMAN_GIT" "${REPOMAN_SRC:-}")"
BAS_C_SRC="$(ensure_git_src bas-c "$BAS_C_GIT" "${BAS_C_SRC:-}")"
fix_bas_c_subprojects "$BAS_C_SRC"

log "sources: getbar=$GETBAR_SRC repoman=$REPOMAN_SRC bas-c=$BAS_C_SRC"

# Docker install may leave root-owned files under WORK/out; clear via docker if needed.
if [[ -e "$WORK" ]]; then
  if ! rm -rf "$WORK" 2>/dev/null; then
    log "clearing root-owned workdir via docker"
    parent="$(dirname "$WORK")"
    base="$(basename "$WORK")"
    docker run --rm -v "$parent:/work" busybox rm -rf "/work/$base"
    rm -rf "$WORK" 2>/dev/null || true
  fi
fi
mkdir -p "$WORK/out" "$WORK/wraps" "$VENDOR"
cp -a "$COMMON/build4-wraps/bash-builtins" "$WORK/wraps/"
cp -a "$COMMON/build4-prescript.sh" "$WORK/prescript.sh"
cp -a "$COMMON/build4-inside.sh" "$WORK/inside.sh"
chmod +x "$WORK/prescript.sh" "$WORK/inside.sh"

# Suite-specific apt bootstrap (EOL archives etc.) — never hardcode mirrors in Dockerfile.
bootstrap_list="$SUITE_DIR/etc/apt/bootstrap/sources.list"
apt_conf_dir="$SUITE_DIR/etc/apt/apt.conf.d"
[[ -f "$bootstrap_list" ]] || die "missing $bootstrap_list (bootstrap apt sources for build4)"

vols=(
  -v "$bootstrap_list:/etc/apt/sources.list:ro"
  -v "$GETBAR_SRC:/src/getbar:ro"
  -v "$REPOMAN_SRC:/src/repoman:ro"
  -v "$BAS_C_SRC:/src/bas-c-src:ro"
  -v "$BAS_SUBPROJECTS:/src/bas-c-subprojects:ro"
  -v "$WORK/wraps:/src/wraps:ro"
  -v "$WORK/out:/out"
)
if [[ -d "$apt_conf_dir" ]]; then
  vols+=(-v "$apt_conf_dir:/etc/apt/apt.conf.d/suite:ro")
fi

keep=()
[[ "${KEEP_BUILD4:-0}" == 1 ]] && keep+=(-k)

log "building getbar/lrm for $TARGET via build4"
(
  cd "$WORK"
  "$BUILD4" -t "$TARGET" \
    "${vols[@]}" \
    "${keep[@]}" \
    -p ./prescript.sh \
    -o "$WORK/build4-copy" \
    -i out \
    ./inside.sh
)

[[ -x "$WORK/out/bin/getbar" ]] || die "getbar missing after build4"
[[ -x "$WORK/out/bin/lrm" ]] || die "lrm missing after build4"

rm -rf "$VENDOR"
mkdir -p "$VENDOR/bin" "$VENDOR/lib" "$VENDOR/share"
cp -a "$WORK/out/." "$VENDOR/"
# Helpers used inside the image during docker build / runtime.
install -m 0755 "$COMMON/apt-via-lrm.sh" "$VENDOR/bin/apt-via-lrm.sh"
install -m 0755 "$COMMON/apt-bootstrap-ca.sh" "$VENDOR/bin/apt-bootstrap-ca.sh"
install -m 0755 "$COMMON/install-lrm-tools.sh" "$VENDOR/bin/install-lrm-tools.sh"

if [[ ! -f "$VENDOR/share/repoman/common.sh" ]]; then
  found="$(find "$VENDOR" -name common.sh -path '*/repoman/*' | head -1 || true)"
  [[ -n "$found" ]] || die "repoman common.sh not in vendor tree"
  mkdir -p "$VENDOR/share/repoman"
  cp -a "$(dirname "$found")/." "$VENDOR/share/repoman/"
fi

log "vendor ready: $VENDOR"
find "$VENDOR" -type f | sed 's|^|  |' | head -40 || true
