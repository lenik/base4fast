#!/bin/bash
# Wrapper: run bundled configrepo (local ISO mirror) before lrm bwsel.
# Soft-fails when the suite is not on the mirror.
set -euo pipefail

export REPO_HOST="${REPO_HOST:-183.131.83.99}"
export REPO_PORT="${REPO_PORT:-1506}"
export REPO_SCHEME="${REPO_SCHEME:-http}"
export REPO_AUTH_USER="${REPO_AUTH_USER:-guest}"
export REPO_AUTH_PASS="${REPO_AUTH_PASS:-V6RiHvGv5a29}"
export SKIP_UPGRADE="${SKIP_UPGRADE:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer sibling next to this script (image: /usr/local/bin/configrepo)
if [[ -x "${SCRIPT_DIR}/configrepo" ]]; then
  exec "${SCRIPT_DIR}/configrepo"
fi
if [[ -x /usr/local/bin/configrepo ]]; then
  exec /usr/local/bin/configrepo
fi
# Dev host checkout
if [[ -x /home/docker/iso-sources/ROOT/configrepo ]]; then
  exec /home/docker/iso-sources/ROOT/configrepo
fi
printf 'configrepo.sh: configrepo binary not found — skip\n' >&2
exit 0
