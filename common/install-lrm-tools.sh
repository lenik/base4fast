#!/bin/bash
# Copy getbar + lrm (+ drm) and repoman library into the image.
# Expects host files already staged under /tmp/lrm-tools/{bin,share}.

set -euo pipefail

SRC="${1:-/tmp/lrm-tools}"

install -d /usr/local/bin /usr/share/repoman
install -m 0755 "$SRC/bin/getbar" /usr/local/bin/getbar
install -m 0755 "$SRC/bin/lrm" /usr/local/bin/lrm
if [[ -f "$SRC/bin/drm" ]]; then
    install -m 0755 "$SRC/bin/drm" /usr/local/bin/drm
fi
cp -a "$SRC/share/repoman/." /usr/share/repoman/

if [[ -d "$SRC/share/bash-completion/completions" ]]; then
    install -d /usr/share/bash-completion/completions
    for c in getbar lrm drm; do
        [[ -f "$SRC/share/bash-completion/completions/$c" ]] || continue
        install -m 0644 "$SRC/share/bash-completion/completions/$c" \
            /usr/share/bash-completion/completions/"$c"
    done
fi

command -v getbar >/dev/null
command -v lrm >/dev/null
