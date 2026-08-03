#!/bin/bash
# Build getbar + repoman (lrm) for a suite using build4.
# Outputs a relocatable tree under <family>/<suite>/build-<arch>/ for COPY
# into the image (BuildKit TARGETARCH → build-${TARGETARCH}/).
#
# Usage: build-lrm-tools.sh FAMILY/SUITE
#   FAMILY/SUITE  debian/bookworm|ubuntu/jammy|centos/s9|…
#
# Sources are git-cloned into extern/ (override with *_SRC or *_GIT):
#   getbar, repoman, bas-c, includes (for bas-c `ninja test`), and optionally
#   subprojects/ (bas-c Meson subprojects; bas-c ships subprojects → ../subprojects).
#
# Environment (optional):
#   BUILD4              path to build4 (default: build4)
#   ARCH                single docker arch: amd64|arm64|loong64 (default: build ARCHES)
#   ARCHES              space-separated arches (default: "amd64 arm64")
#   externdir           clone directory (default: $ROOT/extern)
#   TARGET              override build4 docker image (default derived from FAMILY/SUITE)
#   GETBAR_GIT / REPOMAN_GIT / BAS_C_GIT / INCLUDES_GIT
#   GETBAR_SRC / REPOMAN_SRC / BAS_C_SRC / INCLUDES_SRC
#   BAS_SUBPROJECTS     bas-c subprojects tree (default: $externdir/subprojects, else udisk)
#   VENDOR_UPDATE       if 1, git fetch/reset extern clones from origin (default: 0 — read-only)
#   KEEP_BUILD4         if 1, pass -k to build4

set -euo pipefail

SPEC="${1:?usage: build-lrm-tools.sh FAMILY/SUITE}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scriptsdir="$ROOT/scripts"
externdir="$ROOT/extern"

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

log() { printf 'build-lrm-tools: %s\n' "$*" >&2; }
die() { printf 'build-lrm-tools: error: %s\n' "$*" >&2; exit 1; }

# Build every requested arch (re-enter once per ARCH).
if [[ -z "${_BUILD_LRM_ARCH_INNER:-}" ]]; then
  if [[ -n "${ARCH:-}" ]]; then
    _arches=("$ARCH")
  else
    # shellcheck disable=SC2206
    _arches=(${ARCHES:-amd64 arm64})
  fi
  _rc=0
  for _a in "${_arches[@]}"; do
    log "=== $SPEC arch=$_a ==="
    _BUILD_LRM_ARCH_INNER=1 ARCH="$_a" "$0" "$@" || _rc=$?
  done
  exit "$_rc"
fi

case "${ARCH}" in
amd64|arm64|loong64) ;;
x86_64) ARCH=amd64 ;;
aarch64) ARCH=arm64 ;;
loongarch64) ARCH=loong64 ;;
*) die "unsupported ARCH=$ARCH (want amd64|arm64|loong64)" ;;
esac

SUITE_DIR="$ROOT/$FAMILY/$SUITE"
VENDOR_ROOT="$SUITE_DIR/build-$ARCH"
BUILD4="${BUILD4:-build4}"
GETBAR_GIT="${GETBAR_GIT:-https://github.com/lenik/getbar.git}"
REPOMAN_GIT="${REPOMAN_GIT:-https://github.com/lenik/repoman.git}"
BAS_C_GIT="${BAS_C_GIT:-https://github.com/lenik/bas-c.git}"
INCLUDES_GIT="${INCLUDES_GIT:-https://github.com/lenik/includes.git}"
# bas-c ships subprojects → ../subprojects/; build4-inside copies from
# BAS_SUBPROJECTS into a writable tree (never mutate extern/).
if [[ -z "${BAS_SUBPROJECTS:-}" ]]; then
  if [[ -d "$externdir/subprojects" ]]; then
    BAS_SUBPROJECTS="$externdir/subprojects"
  else
    BAS_SUBPROJECTS="/home/lenik/tasks/udisk/subprojects"
  fi
fi
WORK="$scriptsdir/.build4-work/${FAMILY}-${SUITE}-${ARCH}"
VENDOR_UPDATE="${VENDOR_UPDATE:-0}"
# build4 has no --platform flag; steer docker run/pull via this env.
# Docker platform for LoongArch is linux/loong64 (uname -m is loongarch64).
export DOCKER_DEFAULT_PLATFORM="linux/$ARCH"

# QEMU/binfmt containers often get Docker's 127.0.0.1 DNS stub which does not
# resolve inside the guest. Wrap `docker run` with --network=host for foreign arch.
case "$(uname -m)" in
x86_64|amd64) _host_arch=amd64 ;;
aarch64|arm64) _host_arch=arm64 ;;
*) _host_arch= ;;
esac
if [[ -n "$_host_arch" && "$ARCH" != "$_host_arch" ]]; then
  mkdir -p "$scriptsdir/.build4-work/bin"
  cat >"$scriptsdir/.build4-work/bin/docker" <<'WRAP'
#!/bin/bash
if [[ "$1" == run ]]; then
  shift
  exec /usr/bin/docker run --network=host "$@"
fi
exec /usr/bin/docker "$@"
WRAP
  chmod +x "$scriptsdir/.build4-work/bin/docker"
  export PATH="$scriptsdir/.build4-work/bin:$PATH"
  log "using docker wrapper (--network=host) for foreign ARCH=$ARCH"
fi

# Default build4 target image for FAMILY/SUITE.
default_target() {
  case "$FAMILY" in
  debian)
    # loong64 bases: ghcr.io/loong64/debian for trixie/forky; local sid-loong64 for sid.
    if [[ "$ARCH" == loong64 ]]; then
      case "$SUITE" in
      trixie|stable) printf 'ghcr.io/loong64/debian:trixie\n' ;;
      testing)       printf 'ghcr.io/loong64/debian:forky\n' ;;
      sid)           printf 'debian:sid-loong64\n' ;;
      *)             printf 'debian:sid-loong64\n' ;;
      esac
    else
      printf 'debian:%s\n' "$SUITE"
    fi
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
  openeuler)
    # Hub: openeuler/openeuler:YY.MM (amd64/arm64; 24.03 also loong64).
    # 22.03 loong64: local import openeuler/openeuler:22.03-loong64 (docker_img).
    # 20.03: no loongarch64 OS tree — skip below.
    if [[ "$ARCH" == loong64 ]]; then
      case "$SUITE" in
      24.03) printf 'openeuler/openeuler:24.03\n' ;;
      22.03) printf 'openeuler/openeuler:22.03-loong64\n' ;;
      *)     printf 'openeuler/openeuler:%s\n' "$SUITE" ;;
      esac
    else
      printf 'openeuler/openeuler:%s\n' "$SUITE"
    fi
    ;;
  sles)
    case "$SUITE" in
    # Leap twins for 12/15 (glibc pin); 11 dropped. 16 stays on BCI.
    12.1) printf 'opensuse/archive:42.1\n' ;;
    15.2) printf 'opensuse/leap:15.2\n' ;;
    16.2) printf 'registry.suse.com/bci/bci-base:16.1\n' ;;
    *) die "unknown sles suite: $SUITE" ;;
    esac
    ;;
  *)
    die "unknown family: $FAMILY"
    ;;
  esac
}

TARGET="${TARGET:-$(default_target)}"

# Suites with no usable foreign-arch base image (skip rather than fail).
if [[ "$ARCH" == arm64 ]]; then
  case "$FAMILY/$SUITE" in
  centos/5|centos/6|centos/7|sles/12.1)
    log "skip ARCH=arm64: no linux/arm64 image for $TARGET ($FAMILY/$SUITE)"
    exit 0
    ;;
  esac
fi
if [[ "$ARCH" == loong64 ]]; then
  case "$FAMILY" in
  debian)
    case "$SUITE" in
    # ghcr.io/loong64/debian has trixie/forky; sid uses a local import.
    # Older codenames have no loong64 base.
    stretch|buster|bullseye|bookworm)
      log "skip ARCH=loong64: no loong64 packages for debian/$SUITE (use sid/stable/testing/trixie)"
      exit 0
      ;;
    esac
    ;;
  openeuler)
    case "$SUITE" in
    20.03)
      log "skip ARCH=loong64: openEuler 20.03 has no OS/loongarch64 tree"
      exit 0
      ;;
    22.03|24.03) ;;
    *)
      log "skip ARCH=loong64: unknown openeuler suite $SUITE"
      exit 0
      ;;
    esac
    ;;
  *)
    log "skip ARCH=loong64: only debian/openeuler are wired for loong64 (got $FAMILY/$SUITE)"
    exit 0
    ;;
  esac
fi

# Resolve source tree: use explicit SRC if set, otherwise clone into externdir/<name>.
# Existing clones are treated as read-only (no fetch/checkout) so parallel
# `eachdir make` shares extern/ safely. Set VENDOR_UPDATE=1 to refresh from origin.
ensure_git_src() {
    local name="$1" url="$2" dest="${3:-}"

    if [[ -n "$dest" ]]; then
        [[ -f "$dest/meson.build" ]] || die "$name SRC missing meson.build: $dest"
        log "using existing $name at $dest"
        printf '%s\n' "$dest"
        return 0
    fi

    local dir="$externdir/$name"
    mkdir -p "$externdir"

    if [[ -d "$dir/.git" ]]; then
        if [[ "$VENDOR_UPDATE" == 1 ]]; then
            log "updating $name in $dir (VENDOR_UPDATE=1)"
            # Single-flight refresh: safe if several suites pass VENDOR_UPDATE together.
            (
              flock 9
              git -C "$dir" fetch origin
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
            ) 9>"$externdir/.${name}.lock"
        else
            log "reusing $name at $dir (read-only; VENDOR_UPDATE=1 to refresh)"
        fi
    else
        log "cloning $url → $dir"
        (
          flock 9
          if [[ ! -d "$dir/.git" ]]; then
              rm -rf "$dir"
              git clone --depth 1 "$url" "$dir"
          fi
        ) 9>"$externdir/.${name}.lock"
    fi
    [[ -f "$dir/meson.build" ]] || die "$name missing meson.build after clone: $dir"
    printf '%s\n' "$dir"
}

[[ -x "$BUILD4" ]] || die "build4 not executable: $BUILD4"
[[ -d "$SUITE_DIR" ]] || die "unknown suite dir: $SUITE_DIR"
[[ -d "$BAS_SUBPROJECTS" ]] || die "bas-c subprojects missing: $BAS_SUBPROJECTS"

# Skip if build-<arch> already has matching binaries (FORCE=1 to rebuild).
if [[ "${FORCE:-0}" != 1 && -x "$VENDOR_ROOT/bin/getbar" && -x "$VENDOR_ROOT/bin/lrm" ]]; then
  _ft="$(file -b "$VENDOR_ROOT/bin/getbar" 2>/dev/null || true)"
  if [[ "$_ft" == *"shell script"* ]]; then
    log "skip existing stub $VENDOR_ROOT (FORCE=1 to rebuild)"
    exit 0
  fi
  _want="x86-64"
  [[ "$ARCH" == arm64 ]] && _want="ARM aarch64"
  [[ "$ARCH" == loong64 ]] && _want="LoongArch"
  if [[ "$_ft" == *"$_want"* ]]; then
    log "skip existing $VENDOR_ROOT (FORCE=1 to rebuild)"
    exit 0
  fi
fi

GETBAR_SRC="$(ensure_git_src getbar "$GETBAR_GIT" "${GETBAR_SRC:-}")"
REPOMAN_SRC="$(ensure_git_src repoman "$REPOMAN_GIT" "${REPOMAN_SRC:-}")"
BAS_C_SRC="$(ensure_git_src bas-c "$BAS_C_GIT" "${BAS_C_SRC:-}")"
# Host-side bas-c `meson setup` / `ninja test` needs the includes CLI on PATH
# (apt package or a local build of this tree). Kept in vendor for convenience.
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
mkdir -p "$WORK/out" "$WORK/wraps" "$VENDOR_ROOT"
cp -a "$scriptsdir/build4-wraps/bash-builtins" "$WORK/wraps/"
cp -a "$scriptsdir/build4-inside.sh" "$WORK/inside.sh"
chmod +x "$WORK/inside.sh"

# Host-provided ninja (≥1.8, old glibc) for suites where apt/yum ninja is too
# old or GitHub curl TLS fails (e.g. Ubuntu xenial). Prefer a portable binary
# under build4-bins/; do NOT copy the host distro ninja (often needs new glibc).
# Arch-specific: ninja (amd64 host) or ninja-aarch64 (for linux/arm64 builds).
HOST_NINJA=""
case "$ARCH" in
amd64)
  if [[ -x "$scriptsdir/build4-bins/ninja" ]]; then
    HOST_NINJA="$scriptsdir/build4-bins/ninja"
  fi
  ;;
arm64)
  if [[ -x "$scriptsdir/build4-bins/ninja-aarch64" ]]; then
    HOST_NINJA="$scriptsdir/build4-bins/ninja-aarch64"
  fi
  ;;
esac
if [[ -n "$HOST_NINJA" && "$ARCH" == amd64 ]]; then
  # Sanity: refuse a binary that will not run on glibc 2.17/2.23 targets.
  if ! "$HOST_NINJA" --version >/dev/null 2>&1; then
    log "warning: $HOST_NINJA is not runnable on host; skipping mount"
    HOST_NINJA=""
  fi
elif [[ -n "$HOST_NINJA" ]]; then
  log "will mount $HOST_NINJA for ARCH=$ARCH"
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

HOST_WHEELS="$scriptsdir/build4-bins/wheels"
if [[ -d "$HOST_WHEELS" ]]; then
  vols+=(-v "$HOST_WHEELS:/src/build4-wheels:ro")
  log "mounting pip wheels from $HOST_WHEELS"
fi

HOST_RPMS="$scriptsdir/build4-bins/rpms"
if [[ -d "$HOST_RPMS" ]]; then
  vols+=(-v "$HOST_RPMS:/src/build4-rpms:ro")
  log "mounting bootstrap rpms from $HOST_RPMS"
fi

HOST_LEAP42_REPO="$scriptsdir/build4-bins/leap42.1-repo"
if [[ "$ARCH" == amd64 && -d "$HOST_LEAP42_REPO/x86_64" ]]; then
  vols+=(-v "$HOST_LEAP42_REPO:/src/leap42.1-repo:ro")
  log "mounting local Leap 42.1 repo from $HOST_LEAP42_REPO"
fi

HOST_BOOTSTRAP="$scriptsdir/build4-bins/bootstrap"
if [[ -d "$HOST_BOOTSTRAP" ]]; then
  vols+=(-v "$HOST_BOOTSTRAP:/src/build4-bootstrap:ro")
  log "mounting bootstrap files from $HOST_BOOTSTRAP"
fi

case "$FAMILY" in
debian|ubuntu)
  cp -a "$scriptsdir/build4-prescript.sh" "$WORK/prescript.sh"
  chmod +x "$WORK/prescript.sh"
  bootstrap_list="$SUITE_DIR/etc/apt/bootstrap/sources.list"
  apt_conf_dir="$SUITE_DIR/etc/apt/apt.conf.d"
  [[ -f "$bootstrap_list" ]] || die "missing $bootstrap_list (bootstrap apt sources for build4)"
  # Ubuntu arm64 packages live under ubuntu-ports (not /ubuntu/).
  if [[ "$FAMILY" == ubuntu && "$ARCH" == arm64 ]]; then
    mkdir -p "$WORK/apt-bootstrap"
    sed 's|/ubuntu/|/ubuntu-ports/|g; s|/ubuntu |/ubuntu-ports |g' \
      "$bootstrap_list" >"$WORK/apt-bootstrap/sources.list"
    bootstrap_list="$WORK/apt-bootstrap/sources.list"
    log "ubuntu arm64: using ubuntu-ports bootstrap sources"
  fi
  # loong64 packages: mirrors.loong64.com (ghcr bases); not on regular CN debian mirrors.
  if [[ "$FAMILY" == debian && "$ARCH" == loong64 ]]; then
    mkdir -p "$WORK/apt-bootstrap"
    case "$SUITE" in
    testing)
      _loong_suite=forky
      ;;
    sid)
      _loong_suite=sid
      ;;
    *)
      # trixie / stable / bookworm-era tools against trixie loong64
      _loong_suite=trixie
      ;;
    esac
    if [[ "$_loong_suite" == sid ]]; then
      cat >"$WORK/apt-bootstrap/sources.list" <<EOF
deb http://mirrors.loong64.com/debian/ sid main
EOF
    else
      cat >"$WORK/apt-bootstrap/sources.list" <<EOF
deb http://mirrors.loong64.com/debian/ ${_loong_suite} main
deb http://mirrors.loong64.com/debian/ ${_loong_suite}-updates main
deb http://mirrors.loong64.com/debian-security ${_loong_suite}-security main
EOF
    fi
    bootstrap_list="$WORK/apt-bootstrap/sources.list"
    log "debian loong64: using mirrors.loong64.com ($_loong_suite) bootstrap sources"
  fi
  vols+=(-v "$bootstrap_list:/etc/apt/sources.list:ro")
  if [[ -d "$apt_conf_dir" ]]; then
    vols+=(-v "$apt_conf_dir:/etc/apt/apt.conf.d/suite:ro")
  fi
  ;;
centos|rocky|openeuler)
  cp -a "$scriptsdir/build4-prescript-rpm.sh" "$WORK/prescript.sh"
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
  *openeuler*:20.03|*openeuler/openeuler:20.03*) bootstrap_family=openeuler; bootstrap_suite=20.03 ;;
  *openeuler*:22.03|*openeuler/openeuler:22.03*) bootstrap_family=openeuler; bootstrap_suite=22.03 ;;
  *openeuler*:24.03|*openeuler/openeuler:24.03*) bootstrap_family=openeuler; bootstrap_suite=24.03 ;;
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
  cp -a "$scriptsdir/build4-prescript-zypper.sh" "$WORK/prescript.sh"
  chmod +x "$WORK/prescript.sh"
  # BCI images already ship SLE_BCI; overlaying Leap bootstrap causes solver conflicts.
  zypp_conf="$scriptsdir/zypp-conf/zypp.conf"
  if [[ -f "$zypp_conf" ]]; then
    vols+=(-v "$zypp_conf:/etc/zypp/zypp.conf:ro")
    log "mounting zypp.conf (allowDowngrade) for sles/${SUITE}"
  fi
  # Persist zypper package cache across build4 runs (build4 itself omits zypp).
  zypp_cache="${HOME}/.cache/build4/zypp-${FAMILY}-${SUITE}"
  mkdir -p "$zypp_cache"
  vols+=(-v "$zypp_cache:/var/cache/zypp")
  log "mounting zypp cache $zypp_cache"
  if [[ "$SUITE" == 16.* ]]; then
    log "sles/${SUITE}: keep image SLE_BCI repos (no leap bootstrap overlay)"
  elif [[ "$ARCH" == arm64 ]]; then
    # Leap aarch64 lives under /ports/; CN bootstrap lists are x86_64-only.
    # Keep the image's default ports repos (download.opensuse.org/ports/…).
    log "sles/${SUITE} arm64: keep image ports repos (skip x86_64 bootstrap overlay)"
  else
    bootstrap_repo="$SUITE_DIR/etc/zypp/bootstrap/lrm-bootstrap.repo"
    [[ -f "$bootstrap_repo" ]] || die "missing $bootstrap_repo (bootstrap zypp repos for build4)"
    log "zypp bootstrap from sles/${SUITE} (TARGET=$TARGET)"
    rm -rf "$WORK/zypp.repos.d"
    mkdir -p "$WORK/zypp.repos.d"
    cp -a "$bootstrap_repo" "$WORK/zypp.repos.d/lrm-bootstrap.repo"
    # Prefer axel-prefetched local Leap repo when mounted (suite 12.1 / amd64 only).
    if [[ "$SUITE" == 12.1 && -d "$scriptsdir/build4-bins/leap42.1-repo/x86_64/repodata" ]]; then
      cat > "$WORK/zypp.repos.d/lrm-local.repo" <<'REPO'
[lrm-local-oss]
name=lrm local Leap 42.1 OSS (prefetched)
enabled=1
autorefresh=0
baseurl=file:///src/leap42.1-repo/x86_64
type=rpm-md
gpgcheck=0
keeppackages=1
priority=1
REPO
      log "added lrm-local.repo → file:///src/leap42.1-repo/x86_64"
    fi
    vols+=(-v "$WORK/zypp.repos.d:/etc/zypp/repos.d:ro")
  fi
  ;;
esac

keep=()
[[ "${KEEP_BUILD4:-0}" == 1 ]] && keep+=(-k)

log "building getbar/lrm for $TARGET ($FAMILY/$SUITE/$ARCH) via build4 (platform=$DOCKER_DEFAULT_PLATFORM)"
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

rm -rf "$VENDOR_ROOT"
mkdir -p "$VENDOR_ROOT/bin" "$VENDOR_ROOT/lib" "$VENDOR_ROOT/share"
cp -a "$WORK/out/." "$VENDOR_ROOT/"
# Helpers used inside the image during docker build / runtime.
install -m 0755 "$scriptsdir/install-lrm-tools.sh" "$VENDOR_ROOT/bin/install-lrm-tools.sh"
install -m 0755 "$scriptsdir/install-net-tools.sh" "$VENDOR_ROOT/bin/install-net-tools.sh"
install -m 0755 "$scriptsdir/configrepo.sh" "$VENDOR_ROOT/bin/configrepo.sh"
# Prefer live iso-sources configrepo; fall back to a copy under scripts/.
if [[ -x /home/docker/iso-sources/ROOT/configrepo ]]; then
  install -m 0755 /home/docker/iso-sources/ROOT/configrepo "$VENDOR_ROOT/bin/configrepo"
elif [[ -x "$scriptsdir/configrepo" ]]; then
  install -m 0755 "$scriptsdir/configrepo" "$VENDOR_ROOT/bin/configrepo"
fi
case "$FAMILY" in
debian|ubuntu)
  install -m 0755 "$scriptsdir/apt-via-lrm.sh" "$VENDOR_ROOT/bin/apt-via-lrm.sh"
  install -m 0755 "$scriptsdir/apt-bootstrap-ca.sh" "$VENDOR_ROOT/bin/apt-bootstrap-ca.sh"
  ;;
centos|rocky|openeuler)
  install -m 0755 "$scriptsdir/yum-via-lrm.sh" "$VENDOR_ROOT/bin/yum-via-lrm.sh"
  ;;
sles)
  install -m 0755 "$scriptsdir/zypper-via-lrm.sh" "$VENDOR_ROOT/bin/zypper-via-lrm.sh"
  ;;
esac
# Keep a copy under scripts/ for suites that bake without rebuilding tools.
cp -a "$VENDOR_ROOT/bin/configrepo" "$scriptsdir/configrepo" 2>/dev/null || true

if [[ ! -f "$VENDOR_ROOT/share/repoman/common.sh" ]]; then
  found="$(find "$VENDOR_ROOT" -name common.sh -path '*/repoman/*' | head -1 || true)"
  [[ -n "$found" ]] || die "repoman common.sh not in build-$ARCH tree"
  mkdir -p "$VENDOR_ROOT/share/repoman"
  cp -a "$(dirname "$found")/." "$VENDOR_ROOT/share/repoman/"
fi

log "build-$ARCH ready: $VENDOR_ROOT"
find "$VENDOR_ROOT" -type f | sed 's|^|  |' | head -40 || true
