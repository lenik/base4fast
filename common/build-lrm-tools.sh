#!/bin/bash
# Build getbar + repoman (lrm) for a suite using build4.
# Outputs a relocatable tree under <family>/<suite>/vendor/ for COPY into the image.
#
# Usage: build-lrm-tools.sh FAMILY/SUITE
#   FAMILY/SUITE  debian/bookworm|ubuntu/jammy|centos/s9|…
#
# Sources are git-cloned into common/deps/ (override with *_SRC or *_GIT):
#   getbar, repoman, bas-c, includes (for bas-c `ninja test`), and optionally
#   subprojects/ (bas-c Meson subprojects; bas-c ships subprojects → ../subprojects).
#
# Environment (optional):
#   BUILD4          path to build4 (default: build4)
#   DEPS_DIR        clone directory (default: common/deps)
#   TARGET          override build4 docker image (default derived from FAMILY/SUITE)
#   GETBAR_GIT / REPOMAN_GIT / BAS_C_GIT / INCLUDES_GIT
#   GETBAR_SRC / REPOMAN_SRC / BAS_C_SRC / INCLUDES_SRC
#   BAS_SUBPROJECTS bas-c subprojects tree (default: $DEPS_DIR/subprojects, else udisk)
#   DEPS_UPDATE     if 1, git fetch/reset deps to origin (default: 0 — deps are read-only)
#   KEEP_BUILD4     if 1, pass -k to build4

set -euo pipefail

SPEC="${1:?usage: build-lrm-tools.sh FAMILY/SUITE}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/common"

case "$SPEC" in
*/*)
  FAMILY="${SPEC%%/*}"
  SUITE="${SPEC#*/}"
  ;;
*)
  printf 'build-lrm-tools: error: expected FAMILY/SUITE, got %s\n' "$SPEC" >&2
  exit 1
  ;;
esac

SUITE_DIR="$ROOT/$FAMILY/$SUITE"
VENDOR="$SUITE_DIR/vendor"
BUILD4="${BUILD4:-build4}"
DEPS_DIR="${DEPS_DIR:-$COMMON/deps}"
GETBAR_GIT="${GETBAR_GIT:-https://github.com/lenik/getbar.git}"
REPOMAN_GIT="${REPOMAN_GIT:-https://github.com/lenik/repoman.git}"
BAS_C_GIT="${BAS_C_GIT:-https://github.com/lenik/bas-c.git}"
INCLUDES_GIT="${INCLUDES_GIT:-https://github.com/lenik/includes.git}"
# bas-c ships subprojects → ../subprojects/; build4-inside copies from
# BAS_SUBPROJECTS into a writable tree (never mutate deps/).
if [[ -z "${BAS_SUBPROJECTS:-}" ]]; then
  if [[ -d "$DEPS_DIR/subprojects" ]]; then
    BAS_SUBPROJECTS="$DEPS_DIR/subprojects"
  else
    BAS_SUBPROJECTS="/home/lenik/tasks/udisk/subprojects"
  fi
fi
WORK="$COMMON/.build4-work/${FAMILY}-${SUITE}"
DEPS_UPDATE="${DEPS_UPDATE:-0}"

log() { printf 'build-lrm-tools: %s\n' "$*" >&2; }
die() { printf 'build-lrm-tools: error: %s\n' "$*" >&2; exit 1; }

# Default build4 target image for FAMILY/SUITE.
default_target() {
  case "$FAMILY" in
  debian)
    printf 'debian:%s\n' "$SUITE"
    ;;
  ubuntu)
    printf 'ubuntu:%s\n' "$SUITE"
    ;;
  centos)
    case "$SUITE" in
    s9)  printf 'quay.io/centos/centos:stream9\n' ;;
    s10) printf 'quay.io/centos/centos:stream10\n' ;;
    5|6|7|8) printf 'quay.io/centos/centos:%s\n' "$SUITE" ;;
    *) die "unknown centos suite: $SUITE" ;;
    esac
    ;;
  rocky)
    case "$SUITE" in
    8|9|10) printf 'quay.io/rockylinux/rockylinux:%s\n' "$SUITE" ;;
    *) die "unknown rocky suite: $SUITE" ;;
    esac
    ;;
  sles)
    case "$SUITE" in
    # opensuse/13.2 removed from Docker Hub; build tools on Leap 15.1 (runtime may still use archive twin).
    11) printf 'opensuse/leap:15.1\n' ;;
    12) printf 'registry.suse.com/suse/sles12sp5:latest\n' ;;
    15.1) printf 'opensuse/leap:15.1\n' ;;
    16.1) printf 'registry.suse.com/bci/bci-base:16.1\n' ;;
    *) die "unknown sles suite: $SUITE" ;;
    esac
    ;;
  *)
    die "unknown family: $FAMILY"
    ;;
  esac
}

TARGET="${TARGET:-$(default_target)}"

# Resolve source tree: use explicit SRC if set, otherwise clone into DEPS_DIR/<name>.
# Existing clones are treated as read-only (no fetch/checkout) so parallel
# `eachdir make` shares deps/ safely. Set DEPS_UPDATE=1 to refresh from origin.
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
        if [[ "$DEPS_UPDATE" == 1 ]]; then
            log "updating $name in $dir (DEPS_UPDATE=1)"
            # Single-flight refresh: safe if several suites pass DEPS_UPDATE together.
            (
              flock 9
              git -C "$dir" fetch --depth 1 origin
              git -C "$dir" reset --hard HEAD
              git -C "$dir" clean -fd
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
            ) 9>"$DEPS_DIR/.${name}.lock"
        else
            log "reusing $name at $dir (read-only; DEPS_UPDATE=1 to refresh)"
        fi
    else
        log "cloning $url → $dir"
        (
          flock 9
          if [[ ! -d "$dir/.git" ]]; then
              rm -rf "$dir"
              git clone --depth 1 "$url" "$dir"
          fi
        ) 9>"$DEPS_DIR/.${name}.lock"
    fi
    [[ -f "$dir/meson.build" ]] || die "$name missing meson.build after clone: $dir"
    printf '%s\n' "$dir"
}

[[ -x "$BUILD4" ]] || die "build4 not executable: $BUILD4"
[[ -d "$SUITE_DIR" ]] || die "unknown suite dir: $SUITE_DIR"
[[ -d "$BAS_SUBPROJECTS" ]] || die "bas-c subprojects missing: $BAS_SUBPROJECTS"

GETBAR_SRC="$(ensure_git_src getbar "$GETBAR_GIT" "${GETBAR_SRC:-}")"
REPOMAN_SRC="$(ensure_git_src repoman "$REPOMAN_GIT" "${REPOMAN_SRC:-}")"
BAS_C_SRC="$(ensure_git_src bas-c "$BAS_C_GIT" "${BAS_C_SRC:-}")"
# Host-side bas-c `meson setup` / `ninja test` needs the includes CLI on PATH
# (apt package or a local build of this tree). Kept in deps for convenience.
INCLUDES_SRC="$(ensure_git_src includes "$INCLUDES_GIT" "${INCLUDES_SRC:-}")"

log "sources: getbar=$GETBAR_SRC repoman=$REPOMAN_SRC bas-c=$BAS_C_SRC includes=$INCLUDES_SRC"

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
cp -a "$COMMON/build4-inside.sh" "$WORK/inside.sh"
chmod +x "$WORK/inside.sh"

# Host-provided ninja (≥1.8, old glibc) for suites where apt/yum ninja is too
# old or GitHub curl TLS fails (e.g. Ubuntu xenial). Prefer a portable binary
# under build4-bins/; do NOT copy the host distro ninja (often needs new glibc).
HOST_NINJA="$COMMON/build4-bins/ninja"
if [[ -x "$HOST_NINJA" ]]; then
  # Sanity: refuse a binary that will not run on glibc 2.17/2.23 targets.
  if ! "$HOST_NINJA" --version >/dev/null 2>&1; then
    log "warning: $HOST_NINJA is not runnable on host; skipping mount"
    HOST_NINJA=""
  fi
fi

vols=(
  -v "$GETBAR_SRC:/src/getbar:ro"
  -v "$REPOMAN_SRC:/src/repoman:ro"
  -v "$BAS_C_SRC:/src/bas-c-src:ro"
  -v "$INCLUDES_SRC:/src/includes:ro"
  -v "$BAS_SUBPROJECTS:/src/bas-c-subprojects:ro"
  -v "$WORK/wraps:/src/wraps:ro"
  -v "$WORK/out:/out"
)
if [[ -n "$HOST_NINJA" && -x "$HOST_NINJA" ]]; then
  vols+=(-v "$HOST_NINJA:/usr/local/bin/ninja:ro")
  log "mounting host ninja $($HOST_NINJA --version 2>/dev/null | head -1) → /usr/local/bin/ninja"
fi

case "$FAMILY" in
debian|ubuntu)
  cp -a "$COMMON/build4-prescript.sh" "$WORK/prescript.sh"
  chmod +x "$WORK/prescript.sh"
  bootstrap_list="$SUITE_DIR/etc/apt/bootstrap/sources.list"
  apt_conf_dir="$SUITE_DIR/etc/apt/apt.conf.d"
  [[ -f "$bootstrap_list" ]] || die "missing $bootstrap_list (bootstrap apt sources for build4)"
  vols+=(-v "$bootstrap_list:/etc/apt/sources.list:ro")
  if [[ -d "$apt_conf_dir" ]]; then
    vols+=(-v "$apt_conf_dir:/etc/apt/apt.conf.d/suite:ro")
  fi
  ;;
centos|rocky)
  cp -a "$COMMON/build4-prescript-rpm.sh" "$WORK/prescript.sh"
  chmod +x "$WORK/prescript.sh"
  # When TARGET image differs from SUITE (e.g. centos/5 tools on centos:7),
  # mount the *target* suite bootstrap repos so yum gets matching packages.
  bootstrap_suite="$SUITE"
  bootstrap_family="$FAMILY"
  case "$TARGET" in
  centos:5|*:centos:5) bootstrap_family=centos; bootstrap_suite=5 ;;
  centos:6|*:centos:6) bootstrap_family=centos; bootstrap_suite=6 ;;
  centos:7|*:centos:7) bootstrap_family=centos; bootstrap_suite=7 ;;
  centos:8|*:centos:8) bootstrap_family=centos; bootstrap_suite=8 ;;
  *rockylinux*:8|*rocky*:8) bootstrap_family=rocky; bootstrap_suite=8 ;;
  *rockylinux*:9|*rocky*:9) bootstrap_family=rocky; bootstrap_suite=9 ;;
  *rockylinux*:10|*rocky*:10) bootstrap_family=rocky; bootstrap_suite=10 ;;
  esac
  bootstrap_repo="$ROOT/${bootstrap_family}/${bootstrap_suite}/etc/yum/bootstrap/lrm-bootstrap.repo"
  [[ -f "$bootstrap_repo" ]] || bootstrap_repo="$SUITE_DIR/etc/yum/bootstrap/lrm-bootstrap.repo"
  [[ -f "$bootstrap_repo" ]] || die "missing $bootstrap_repo (bootstrap yum repos for build4)"
  log "yum bootstrap from ${bootstrap_family}/${bootstrap_suite} (TARGET=$TARGET)"
  rm -rf "$WORK/yum.repos.d"
  mkdir -p "$WORK/yum.repos.d"
  cp -a "$bootstrap_repo" "$WORK/yum.repos.d/lrm-bootstrap.repo"
  vols+=(-v "$WORK/yum.repos.d:/etc/yum.repos.d:ro")
  ;;
sles)
  cp -a "$COMMON/build4-prescript-zypper.sh" "$WORK/prescript.sh"
  chmod +x "$WORK/prescript.sh"
  bootstrap_repo="$SUITE_DIR/etc/zypp/bootstrap/lrm-bootstrap.repo"
  [[ -f "$bootstrap_repo" ]] || die "missing $bootstrap_repo (bootstrap zypp repos for build4)"
  log "zypp bootstrap from sles/${SUITE} (TARGET=$TARGET)"
  rm -rf "$WORK/zypp.repos.d"
  mkdir -p "$WORK/zypp.repos.d"
  cp -a "$bootstrap_repo" "$WORK/zypp.repos.d/lrm-bootstrap.repo"
  vols+=(-v "$WORK/zypp.repos.d:/etc/zypp/repos.d:ro")
  ;;
esac

keep=()
[[ "${KEEP_BUILD4:-0}" == 1 ]] && keep+=(-k)

log "building getbar/lrm for $TARGET ($FAMILY/$SUITE) via build4"
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
install -m 0755 "$COMMON/install-lrm-tools.sh" "$VENDOR/bin/install-lrm-tools.sh"
case "$FAMILY" in
debian|ubuntu)
  install -m 0755 "$COMMON/apt-via-lrm.sh" "$VENDOR/bin/apt-via-lrm.sh"
  install -m 0755 "$COMMON/apt-bootstrap-ca.sh" "$VENDOR/bin/apt-bootstrap-ca.sh"
  ;;
centos|rocky)
  install -m 0755 "$COMMON/yum-via-lrm.sh" "$VENDOR/bin/yum-via-lrm.sh"
  ;;
sles)
  install -m 0755 "$COMMON/zypper-via-lrm.sh" "$VENDOR/bin/zypper-via-lrm.sh"
  ;;
esac

if [[ ! -f "$VENDOR/share/repoman/common.sh" ]]; then
  found="$(find "$VENDOR" -name common.sh -path '*/repoman/*' | head -1 || true)"
  [[ -n "$found" ]] || die "repoman common.sh not in vendor tree"
  mkdir -p "$VENDOR/share/repoman"
  cp -a "$(dirname "$found")/." "$VENDOR/share/repoman/"
fi

log "vendor ready: $VENDOR"
find "$VENDOR" -type f | sed 's|^|  |' | head -40 || true
