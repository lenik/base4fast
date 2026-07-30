#!/bin/bash
# Create a minimal vendor/ for EOL CentOS 5/6 where Meson/Python3 cannot
# run (and getbar/lrm built on EL7+ will not link against the old glibc).
# The image uses fixed HTTP vault mirrors instead of lrm bwsel.
#
# Usage: build-lrm-tools-stub.sh FAMILY/SUITE

set -euo pipefail

SPEC="${1:?usage: build-lrm-tools-stub.sh FAMILY/SUITE}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/common"

case "$SPEC" in
*/*)
  FAMILY="${SPEC%%/*}"
  SUITE="${SPEC#*/}"
  ;;
*)
  printf 'build-lrm-tools-stub: error: expected FAMILY/SUITE, got %s\n' "$SPEC" >&2
  exit 1
  ;;
esac

SUITE_DIR="$ROOT/$FAMILY/$SUITE"
VENDOR="$SUITE_DIR/vendor"

log() { printf 'build-lrm-tools-stub: %s\n' "$*" >&2; }
die() { printf 'build-lrm-tools-stub: error: %s\n' "$*" >&2; exit 1; }

[[ -d "$SUITE_DIR" ]] || die "missing suite dir $SUITE_DIR"
[[ "$FAMILY" == centos ]] || die "stub tools only for centos (got $FAMILY)"
case "$SUITE" in
5|6) ;;
*) die "stub tools only for centos/5 and centos/6 (got $SUITE)" ;;
esac

rm -rf "$VENDOR"
mkdir -p "$VENDOR/bin" "$VENDOR/lib" "$VENDOR/share/repoman"

install -m 0755 "$COMMON/yum-via-lrm.sh" "$VENDOR/bin/yum-via-lrm.sh"
install -m 0755 "$COMMON/install-lrm-tools.sh" "$VENDOR/bin/install-lrm-tools.sh" 2>/dev/null || true

cat >"$VENDOR/bin/getbar" <<'EOF'
#!/bin/sh
echo "getbar: stub (centos ${CENTOS_STUB:-5/6} — fixed HTTP vault mirrors; no bwsel)" >&2
exit 0
EOF
chmod 0755 "$VENDOR/bin/getbar"

cat >"$VENDOR/bin/lrm" <<EOF
#!/bin/sh
echo "lrm stub ${FAMILY}/${SUITE} (fixed vault mirrors; bwsel disabled)" >&2
echo "lrm 0.0.0-stub"
exit 0
EOF
chmod 0755 "$VENDOR/bin/lrm"

# Minimal share tree so accidental lrm paths don't explode.
printf '# stub repoman share for %s/%s\n' "$FAMILY" "$SUITE" \
  >"$VENDOR/share/repoman/README.stub"

log "vendor ready (stub): $VENDOR"
find "$VENDOR" -type f | sed 's|^|  |'
