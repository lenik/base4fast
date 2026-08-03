#!/bin/bash
# Guard qemu-user cross-arch docker builds when host memory is tight.
# No interactive prompt: warn and refuse (caller skips foreign arches).
#
# Usage: warn-cross-qemu.sh [docker-arch ...]
#   arches: amd64|arm64|loong64|… (omit = nothing to check)
#
# Environment:
#   CROSS_QEMU_OK=1          allow qemu cross-arch despite low memory
#   CROSS_QEMU_MIN_AVAIL_MB  MemAvailable threshold (default 6144)
#   CROSS_QEMU_MAX_SWAP_MB  refuse if SwapUsed already above this (default 512)
#
# Exit:
#   0  OK to build all requested arches (native-only, or cross with enough RAM,
#      or CROSS_QEMU_OK=1)
#   2  memory risk — caller should SKIP foreign/qemu arches (warn already printed)
#   1  usage / internal error

set -euo pipefail

log() { printf 'warn-cross-qemu: %s\n' "$*" >&2; }

host_docker_arch() {
  case "$(uname -m)" in
  x86_64|amd64) echo amd64 ;;
  aarch64|arm64) echo arm64 ;;
  loongarch64) echo loong64 ;;
  ppc64le) echo ppc64le ;;
  s390x) echo s390x ;;
  riscv64) echo riscv64 ;;
  *) uname -m ;;
  esac
}

norm_arch() {
  case "$1" in
  x86_64|amd64) echo amd64 ;;
  aarch64|arm64) echo arm64 ;;
  loongarch64|loong64) echo loong64 ;;
  *) echo "$1" ;;
  esac
}

mem_available_mb() {
  awk '/^MemAvailable:/ {print int($2/1024); exit}' /proc/meminfo
}

swap_used_mb() {
  awk '/^SwapTotal:/ {t=$2} /^SwapFree:/ {f=$2} END {print int((t-f)/1024)}' /proc/meminfo
}

swap_total_mb() {
  awk '/^SwapTotal:/ {print int($2/1024); exit}' /proc/meminfo
}

HOST="$(host_docker_arch)"
MIN_AVAIL_MB="${CROSS_QEMU_MIN_AVAIL_MB:-6144}"
MAX_SWAP_MB="${CROSS_QEMU_MAX_SWAP_MB:-512}"

FOREIGN=()
for a in "$@"; do
  [[ -z "$a" ]] && continue
  na="$(norm_arch "$a")"
  if [[ "$na" != "$HOST" ]]; then
    FOREIGN+=("$na")
  fi
done

if [[ ${#FOREIGN[@]} -eq 0 ]]; then
  exit 0
fi

mapfile -t FOREIGN < <(printf '%s\n' "${FOREIGN[@]}" | sort -u)

AVAIL="$(mem_available_mb)"
SWAPU="$(swap_used_mb)"
SWAPT="$(swap_total_mb)"

risk=0
reasons=()
if [[ "$AVAIL" -lt "$MIN_AVAIL_MB" ]]; then
  risk=1
  reasons+=("MemAvailable ${AVAIL}MiB < ${MIN_AVAIL_MB}MiB")
fi
if [[ "$SWAPU" -gt "$MAX_SWAP_MB" ]]; then
  risk=1
  reasons+=("Swap already in use ${SWAPU}MiB (threshold ${MAX_SWAP_MB}MiB)")
fi

log "cross-arch needs qemu-user: host=$HOST foreign=${FOREIGN[*]}"
log "memory: MemAvailable=${AVAIL}MiB SwapUsed=${SWAPU}MiB/${SWAPT}MiB"

if [[ "$risk" -eq 0 ]]; then
  log "memory OK for qemu (avail>=${MIN_AVAIL_MB}MiB, swap_used<=${MAX_SWAP_MB}MiB)"
  exit 0
fi

log "WARNING: low memory / swap pressure — refusing qemu-user cross build"
log "         (bwsel + dnf makecache under qemu thrash swap and look stuck)."
for r in "${reasons[@]}"; do
  log "  - $r"
done
log "skip foreign arches: ${FOREIGN[*]}"
log "bake native only: bake-suite.sh FAMILY/SUITE $HOST"
log "or free RAM, or set CROSS_QEMU_OK=1 to force"

case "${CROSS_QEMU_OK:-}" in
1|yes|true|YES|TRUE)
  log "CROSS_QEMU_OK=${CROSS_QEMU_OK} — forcing continue"
  exit 0
  ;;
esac

exit 2
