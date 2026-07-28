#!/bin/bash
# Bootstrap ca-certificates when lrm.sources uses HTTPS but the CA store is empty.
# Minimal Debian images fail apt HTTPS fetches until ca-certificates is installed.

set -euo pipefail

sources="/etc/apt/sources.list.d/lrm.sources"

log() {
    printf 'apt-bootstrap-ca: %s\n' "$*" >&2
}

if dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null | grep -q 'install ok installed'; then
    exit 0
fi

[[ -f "$sources" ]] || exit 0
grep -q '^URIs: https://' "$sources" || exit 0

log "installing ca-certificates over HTTP"
sed -i 's|^URIs: https://|URIs: http://|g' "$sources"
apt-get update
apt-get install -y --no-install-recommends ca-certificates
sed -i 's|^URIs: http://|URIs: https://|g' "$sources"
log "restored HTTPS URIs in $sources"
