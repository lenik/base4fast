#!/bin/bash
# Select the fastest mirror with lrm bwsel and refresh yum/dnf metadata.
# Must run before package installs in China; never keep vendor default repos.
#
# Usage: yum-via-lrm.sh DISTRO_SPEC [bwsel options...]
#   DISTRO_SPEC  e.g. centos:7, centos:9, centos:10
#   extra args   forwarded to `lrm bwsel` (e.g. --everything --epel)

set -euo pipefail

log() {
    printf 'yum-via-lrm: %s\n' "$*" >&2
}

die() {
    printf 'yum-via-lrm: error: %s\n' "$*" >&2
    exit 1
}

purge_default_yum_repos() {
    local f
    mkdir -p /etc/yum.repos.d/bak
    shopt -s nullglob
    for f in /etc/yum.repos.d/*.repo; do
        case "$(basename "$f")" in
        lrm.repo|lrm-bootstrap.repo) continue ;;
        esac
        mv -f "$f" /etc/yum.repos.d/bak/
    done
    shopt -u nullglob
}

# dnf/yum upgrade often reinstalls *-repos packages that restore dead
# mirrorlist.centos.org (EOL CentOS 8) or vendor defaults. Call after upgrade.
purge_non_lrm_repos() {
    purge_default_yum_repos
    log "purged non-lrm yum/dnf repos (kept lrm.repo / lrm-bootstrap.repo)"
}

refresh_rpm_metadata() {
    if command -v dnf >/dev/null 2>&1; then
        dnf clean metadata >/dev/null 2>&1 || true
        dnf -y makecache || dnf check-update || true
    elif command -v yum >/dev/null 2>&1; then
        yum clean metadata >/dev/null 2>&1 || true
        yum -y makecache || yum check-update || true
    else
        die "neither dnf nor yum found"
    fi
}

main() {
    local distro_spec=""
    local config_only=0
    local purge_only=0
    local arg
    local -a bwsel_args=()

    export PATH="/usr/local/bin:${PATH}"
    export LRM_GETBAR="${LRM_GETBAR:-getbar}"

    if [[ "${1:-}" == "--purge-only" ]]; then
        purge_non_lrm_repos
        return 0
    fi

    distro_spec="${1:?distro required (centos|centos:N) or --purge-only}"
    shift

    command -v lrm >/dev/null 2>&1 || die "lrm not found"
    command -v getbar >/dev/null 2>&1 || die "getbar not found (needed by lrm bwsel)"

    for arg in "$@"; do
        case "$arg" in
        -c|--config-only) config_only=1 ;;
        --purge-only) purge_only=1 ;;
        *) bwsel_args+=("$arg") ;;
        esac
    done

    if [[ "$purge_only" -eq 1 ]]; then
        purge_non_lrm_repos
        return 0
    fi

    purge_default_yum_repos
    # Drop bootstrap once lrm will write lrm.repo.
    rm -f /etc/yum.repos.d/lrm-bootstrap.repo

    log "running lrm bwsel for ${distro_spec}${bwsel_args[*]:+ (${bwsel_args[*]})}"
    lrm --distro "$distro_spec" bwsel "${bwsel_args[@]}"

    # CentOS 5/6 OpenSSL/M2Crypto cannot speak modern HTTPS mirrors.
    case "$distro_spec" in
    centos:5|centos:6|centos5|centos6)
      if [[ -f /etc/yum.repos.d/lrm.repo ]]; then
        log "forcing HTTP baseurls for ${distro_spec} (legacy TLS)"
        sed -i 's|https://|http://|g' /etc/yum.repos.d/lrm.repo
      fi
      ;;
    esac

    if [[ "$config_only" -eq 0 ]]; then
        refresh_rpm_metadata
    else
        log "skipping yum/dnf makecache (--config-only)"
    fi
}

main "$@"
