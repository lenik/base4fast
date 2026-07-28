#!/bin/bash
# Select the fastest mirror with lrm bwtest/bwsel and refresh package metadata.
# Must run before any apt-get install in China; never use vendor default repos.
#
# Usage: apt-via-lrm.sh DISTRO_SPEC [bwsel options...]
#   DISTRO_SPEC  e.g. debian, debian:bookworm, debian:trixie
#   extra args   forwarded to `lrm bwsel` (e.g. --no-security --no-backports)

set -euo pipefail

log() {
    printf 'apt-via-lrm: %s\n' "$*" >&2
}

die() {
    printf 'apt-via-lrm: error: %s\n' "$*" >&2
    exit 1
}

purge_default_apt_sources() {
    rm -f /etc/apt/sources.list
    rm -f /etc/apt/sources.list.d/debian.sources
    rm -f /etc/apt/sources.list.d/ubuntu.sources
    rm -f /etc/apt/sources.list.d/bootstrap.sources
}

apt_ca_store_ready() {
    dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null | grep -q 'install ok installed'
}

bootstrap_apt_ca_store() {
    local sources="/etc/apt/sources.list.d/lrm.sources"

    apt_ca_store_ready && return 0
    [[ -f "$sources" ]] || return 0
    grep -q '^URIs: https://' "$sources" || return 0

    log "bootstrapping ca-certificates over HTTP (minimal image has no CA store)"
    sed -i 's|^URIs: https://|URIs: http://|g' "$sources"
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates
    sed -i 's|^URIs: http://|URIs: https://|g' "$sources"
}

refresh_apt_metadata() {
    bootstrap_apt_ca_store

    # Old apt + some China HTTPS CDNs hang or stall; prefer HTTP for
    # debian-archive mirrors (content is identical, TLS adds no value for EOL).
    local sources="/etc/apt/sources.list.d/lrm.sources"
    if [[ -f "$sources" ]] && grep -q 'debian-archive' "$sources"; then
        log "using HTTP for debian-archive mirror (EOL suite)"
        sed -i 's|^URIs: https://|URIs: http://|g' "$sources"
    fi

    # Bound network stalls so image builds fail fast instead of hanging.
    apt-get \
        -o Acquire::Retries=3 \
        -o Acquire::http::Timeout=30 \
        -o Acquire::https::Timeout=30 \
        update
}

main() {
    local distro_spec="${1:?distro required (debian|debian:suite)}"
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

    purge_default_apt_sources
    log "running lrm bwsel for ${distro_spec}${*:+ ($*)}"
    lrm --distro "$distro_spec" bwsel "$@"
    if [[ "$config_only" -eq 0 ]]; then
        refresh_apt_metadata
    else
        log "skipping apt-get update (--config-only)"
    fi
}

main "$@"
