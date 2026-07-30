#!/bin/bash
# Select the fastest mirror with lrm bwsel and refresh zypper metadata.
# Must run before package installs in China; never keep vendor default repos.
#
# Usage: zypper-via-lrm.sh DISTRO_SPEC [bwsel options...]
#   DISTRO_SPEC  e.g. sles:15.2, sles:16.2, opensuse:15.6
#   extra args   forwarded to `lrm bwsel`

set -euo pipefail

log() {
    printf 'zypper-via-lrm: %s\n' "$*" >&2
}

die() {
    printf 'zypper-via-lrm: error: %s\n' "$*" >&2
    exit 1
}

purge_default_zypp_repos() {
    local f
    mkdir -p /etc/zypp/repos.d/bak
    shopt -s nullglob
    for f in /etc/zypp/repos.d/*.repo; do
        case "$(basename "$f")" in
        lrm.repo|lrm-bootstrap.repo) continue ;;
        esac
        mv -f "$f" /etc/zypp/repos.d/bak/
    done
    shopt -u nullglob
}

refresh_zypp_metadata() {
    if ! command -v zypper >/dev/null 2>&1; then
        die "zypper not found"
    fi
    zypper --non-interactive --gpg-auto-import-keys refresh \
        || zypper --non-interactive refresh || true
}

main() {
    local distro_spec="${1:?distro required (sles|sles:N|opensuse:N)}"
    shift
    local config_only=0
    local arg

    export PATH="/usr/local/bin:${PATH}"
    export LRM_GETBAR="${LRM_GETBAR:-getbar}"

    command -v lrm >/dev/null 2>&1 || die "lrm not found"
    command -v getbar >/dev/null 2>&1 || die "getbar not found (needed by lrm bwsel)"

    for arg in "$@"; do
        case "$arg" in
        -c|--config-only) config_only=1 ;;
        esac
    done

    purge_default_zypp_repos
    rm -f /etc/zypp/repos.d/lrm-bootstrap.repo

    log "running lrm bwsel for ${distro_spec}${*:+ ($*)}"
    lrm --distro "$distro_spec" bwsel "$@"

    if [[ "$config_only" -eq 0 ]]; then
        refresh_zypp_metadata
    else
        log "skipping zypper refresh (--config-only)"
    fi
}

main "$@"
