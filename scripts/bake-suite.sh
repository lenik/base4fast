#!/bin/bash
# Build tools + docker buildx bake for one FAMILY/SUITE, optionally filtered by ARCH.
#
# Usage: bake-suite.sh FAMILY/SUITE [ARCH]
#   ARCH  amd64|arm64|loong64  (omit = all targets in the suite default group)
#
# Environment:
#   BUILD4     path to build4 (default: build4 on PATH)
#   SKIP_TOOLS 1 = do not rebuild getbar/lrm
#   PULL       prefer|never|always (default: prefer)
#                never  — local bases only; skip targets whose FROM image/platform
#                         is not already in `docker images` (no Hub wait)
#                prefer — same as never when local bases exist and age ≤ PULL_MAX_AGE;
#                         otherwise try Hub; on Hub timeout fall back to local-only
#                always — ask Hub first; on timeout fall back to local-only
#   PULL_MAX_AGE  max age of local bases before prefer rechecks Hub (default 168h).
#                 0 = always recheck Hub in prefer mode.

set -euo pipefail

SPEC="${1:?usage: bake-suite.sh FAMILY/SUITE [ARCH]}"
ARCH="${2:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUITE_DIR="$ROOT/$SPEC"

log() { printf 'bake-suite: %s\n' "$*" >&2; }
die() { printf 'bake-suite: error: %s\n' "$*" >&2; exit 1; }

[[ -f "$SUITE_DIR/docker-bake.hcl" ]] || die "missing $SUITE_DIR/docker-bake.hcl"
[[ -f "$SUITE_DIR/Makefile" ]] || die "missing $SUITE_DIR/Makefile"

BUILD4="${BUILD4:-$(command -v build4 || true)}"
[[ -n "$BUILD4" && -x "$BUILD4" ]] || die "build4 not found (set BUILD4=)"

case "${PULL:-prefer}" in
0|never|false|no)       PULL_MODE=never ;;
1|always|true|yes)      PULL_MODE=always ;;
prefer|auto|missing|"") PULL_MODE=prefer ;;
*) die "unsupported PULL=${PULL:-} (want prefer|never|always)" ;;
esac
PULL_MAX_AGE="${PULL_MAX_AGE:-168h}"

cd "$SUITE_DIR"

if [[ "${SKIP_TOOLS:-0}" != "1" ]]; then
  if [[ -n "$ARCH" ]]; then
    case "$ARCH" in
    amd64|arm64|loong64) ;;
    *) die "unsupported ARCH=$ARCH (want amd64|arm64|loong64)" ;;
    esac
    log "tools $SPEC ARCH=$ARCH"
    BUILD4="$BUILD4" ARCH="$ARCH" "$ROOT/scripts/build-lrm-tools.sh" "$SPEC"
  else
    log "tools $SPEC (suite Makefile arches)"
    BUILD4="$BUILD4" make tools
  fi
fi

bake_print_json() {
  BUILDX_BAKE_ENTITLEMENTS_FS=0 docker buildx bake --print "$@" 2>/dev/null
}

mapfile -t ALL_TARGETS < <(
  bake_print_json | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(sorted(d.get("target",{}))))'
)
[[ ${#ALL_TARGETS[@]} -gt 0 ]] || die "no bake targets in $SPEC"

SELECTED=()
if [[ -z "$ARCH" ]]; then
  SELECTED=("${ALL_TARGETS[@]}")
else
  for t in "${ALL_TARGETS[@]}"; do
    case "$ARCH" in
    amd64)
      if [[ "$t" == *-amd64 || "$t" == "base-image" ]]; then
        SELECTED+=("$t")
      fi
      ;;
    arm64)   [[ "$t" == *-arm64 ]] && SELECTED+=("$t") ;;
    loong64) [[ "$t" == *loong64* ]] && SELECTED+=("$t") ;;
    esac
  done
fi

if [[ ${#SELECTED[@]} -eq 0 ]]; then
  log "skip $SPEC: no targets for ARCH=${ARCH:-all}"
  exit 0
fi

# Filter SELECTED to targets whose BASE_IMAGE exists locally for the target platform.
# Targets without BASE_IMAGE arg are kept (FROM hardcoded in Dockerfile).
# Prints kept names on stdout; skip reasons on stderr.
filter_local_platform_bases() {
  bake_print_json "${SELECTED[@]}" | python3 -c '
import json, subprocess, sys

d = json.load(sys.stdin)
want = set(sys.argv[1:])
kept = []

def arch_of(t):
    plats = t.get("platforms") or t.get("platform") or []
    if isinstance(plats, str):
        plats = [plats]
    if not plats:
        return None
    return plats[0].rsplit("/", 1)[-1]

def local_arch(img):
    r = subprocess.run(
        ["docker", "image", "inspect", img, "--format", "{{.Architecture}}"],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        return None
    return r.stdout.strip()

for name in sorted(want):
    t = d.get("target", {}).get(name)
    if not t:
        continue
    args = t.get("args") or {}
    img = args.get("BASE_IMAGE") or args.get("base_image")
    if not img:
        kept.append(name)
        continue
    need = arch_of(t)
    have = local_arch(img)
    if have is None:
        print(f"bake-suite: skip {name}: no local {img}", file=sys.stderr)
        continue
    if need and have != need:
        print(f"bake-suite: skip {name}: local {img} is {have}, need {need}", file=sys.stderr)
        continue
    kept.append(name)

if kept:
    print("\n".join(kept))
' "${SELECTED[@]}"
}

locals_fresh_enough() {
  local img created created_ts max_sec now
  [[ "$PULL_MAX_AGE" == "0" ]] && return 1
  max_sec=$(python3 -c '
import re,sys
s=sys.argv[1].strip().lower()
m=re.fullmatch(r"(\d+)([smhdw]?)", s)
if not m: raise SystemExit(2)
n,u=int(m.group(1)), (m.group(2) or "s")
print(n*{"s":1,"m":60,"h":3600,"d":86400,"w":604800}[u])
' "$PULL_MAX_AGE") || return 1
  now=$(date +%s)
  local imgs
  mapfile -t imgs < <(
    bake_print_json "${SELECTED[@]}" | python3 -c '
import json,sys
d=json.load(sys.stdin)
seen=set()
for t in d.get("target",{}).values():
    img=(t.get("args") or {}).get("BASE_IMAGE") or (t.get("args") or {}).get("base_image")
    if img and img not in seen:
        seen.add(img); print(img)
'
  )
  [[ ${#imgs[@]} -gt 0 ]] || return 1
  for img in "${imgs[@]}"; do
    docker image inspect "$img" >/dev/null 2>&1 || return 1
    created=$(docker image inspect "$img" --format '{{.Created}}')
    created_ts=$(date -d "$created" +%s 2>/dev/null || date -d "$(echo "$created" | cut -c1-19)" +%s) || return 1
    if (( now - created_ts > max_sec )); then
      log "local $img older than PULL_MAX_AGE=$PULL_MAX_AGE"
      return 1
    fi
  done
  return 0
}

run_bake() {
  local mode=$1
  shift
  local -a targets=()
  local t
  for t in "$@"; do
    [[ -n "$t" ]] && targets+=("$t")
  done
  if [[ ${#targets[@]} -eq 0 ]]; then
    log "run_bake: no targets (mode=$mode) — skip"
    return 0
  fi
  local -a args=(--allow=network.host)
  case "$mode" in
  never)  args+=(--set '*.pull=false') ;;
  always) args+=(--pull=true) ;;
  esac
  # Dockerd systemd HTTP_PROXY is for registry pulls only. Clear client + bake
  # args so BuildKit does not inject the proxy into RUN (container network).
  args+=(
    --set '*.args.HTTP_PROXY='
    --set '*.args.HTTPS_PROXY='
    --set '*.args.http_proxy='
    --set '*.args.https_proxy='
    --set '*.args.ALL_PROXY='
    --set '*.args.all_proxy='
    --set '*.args.NO_PROXY=*'
    --set '*.args.no_proxy=*'
  )
  log "bake targets (${mode}): ${targets[*]}"
  env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
      -u ALL_PROXY -u all_proxy \
    BUILDX_BAKE_ENTITLEMENTS_FS=0 docker buildx bake "${args[@]}" "${targets[@]}"
}

is_hub_transient() {
  grep -Eqi \
    'DeadlineExceeded|i/o timeout|TLS handshake timeout|failed to fetch (oauth |anonymous )?token|connection reset|no such host|Temporary failure in name resolution|auth\.docker\.io|registry-1\.docker\.io|Client\.Timeout' \
    "$1"
}

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

mapfile -t _local_raw < <(filter_local_platform_bases)
LOCAL_TARGETS=()
for t in "${_local_raw[@]+"${_local_raw[@]}"}"; do
  [[ -n "$t" ]] && LOCAL_TARGETS+=("$t")
done
HUB_TARGETS=()
for t in "${SELECTED[@]}"; do
  keep=0
  for l in "${LOCAL_TARGETS[@]+"${LOCAL_TARGETS[@]}"}"; do
    [[ "$t" == "$l" ]] && keep=1 && break
  done
  [[ $keep -eq 0 ]] && HUB_TARGETS+=("$t")
done

_local_fmt=${LOCAL_TARGETS[*]:-none}
_hub_fmt=${HUB_TARGETS[*]:-none}
log "bake $SPEC (PULL=$PULL_MODE): local=${_local_fmt} hub-needed=${_hub_fmt}"

set +e
rc=0

bake_local() {
  if [[ ${#LOCAL_TARGETS[@]} -eq 0 ]]; then
    log "no local-platform targets to bake"
    return 0
  fi
  log "baking with local bases (pull=false): ${LOCAL_TARGETS[*]}"
  run_bake never "${LOCAL_TARGETS[@]}" 2>&1 | tee "$LOG"
  return "${PIPESTATUS[0]}"
}

bake_hub() {
  local -a targets=("$@")
  [[ ${#targets[@]} -gt 0 ]] || return 0
  log "baking with Hub pull: ${targets[*]}"
  run_bake always "${targets[@]}" 2>&1 | tee "$LOG"
  return "${PIPESTATUS[0]}"
}

case "$PULL_MODE" in
never)
  if [[ ${#LOCAL_TARGETS[@]} -eq 0 ]]; then
    log "skip $SPEC: no local bases for selected targets (PULL=never)"
    exit 0
  fi
  if [[ ${#HUB_TARGETS[@]} -gt 0 ]]; then
    log "note: skipping (no local base): ${HUB_TARGETS[*]}"
  fi
  bake_local
  rc=$?
  ;;
always)
  bake_hub "${SELECTED[@]}"
  rc=$?
  if [[ $rc -ne 0 ]] && is_hub_transient "$LOG"; then
    log "Hub unreachable — falling back to local-only targets"
    if [[ ${#LOCAL_TARGETS[@]} -eq 0 ]]; then
      log "FAIL $SPEC: Hub down and no usable local bases"
      exit 1
    fi
    bake_local
    rc=$?
  fi
  ;;
prefer)
  # Local-first: build what we already have. Do not block on Hub for missing
  # bases (Hub auth often times out here). Only recheck Hub when every selected
  # target already has a local base but it is older than PULL_MAX_AGE.
  if [[ ${#LOCAL_TARGETS[@]} -eq 0 ]]; then
    log "no local bases for $SPEC — trying Hub (PULL=prefer)"
    bake_hub "${SELECTED[@]}"
    rc=$?
    if [[ $rc -ne 0 ]] && is_hub_transient "$LOG"; then
      log "skip $SPEC: Hub down and no usable local bases for this arch"
      rc=0
    fi
  elif [[ ${#HUB_TARGETS[@]} -gt 0 ]]; then
    log "note: skipping (no local base; set PULL=always to fetch): ${HUB_TARGETS[*]}"
    bake_local
    rc=$?
  elif locals_fresh_enough; then
    log "all bases local and within PULL_MAX_AGE — skipping Hub"
    bake_local
    rc=$?
  else
    log "local bases older than PULL_MAX_AGE — rechecking Hub"
    bake_hub "${SELECTED[@]}"
    rc=$?
    if [[ $rc -ne 0 ]] && is_hub_transient "$LOG"; then
      log "Hub unreachable — using local cache anyway (may be stale)"
      bake_local
      rc=$?
    fi
  fi
  ;;
esac
set -e

if [[ $rc -ne 0 ]]; then
  log "FAIL $SPEC (exit $rc)"
  exit "$rc"
fi
log "OK $SPEC"
exit 0
