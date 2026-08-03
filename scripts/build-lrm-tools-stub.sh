#!/bin/bash
# Create minimal build-<arch>/ trees  for EOL CentOS 5/6 where Meson/Python3 cannot
# run (and getbar/lrm built on EL7+ will not link against the old glibc).
# The image uses fixed HTTP vault mirrors instead of lrm bwsel.
#
# Usage: build-lrm-tools-stub.sh FAMILY/SUITE

set -euo pipefail

SPEC="${1:?usage: build-lrm-tools-stub.sh FAMILY/SUITE}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scriptsdir="$ROOT/scripts"

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
ARCHES="${ARCHES:-${ARCH:-amd64 arm64}}"

log() { printf 'build-lrm-tools-stub: %s\n' "$*" >&2; }
die() { printf 'build-lrm-tools-stub: error: %s\n' "$*" >&2; exit 1; }

[[ -d "$SUITE_DIR" ]] || die "missing suite dir $SUITE_DIR"
[[ "$FAMILY" == centos ]] || die "stub tools only for centos (got $FAMILY)"
case "$SUITE" in
5|6) ;;
*) die "stub tools only for centos/5 and centos/6 (got $SUITE)" ;;
esac

# shellcheck disable=SC2206
for ARCH in $ARCHES; do
  case "$ARCH" in amd64|arm64) ;; *) die "unsupported ARCH=$ARCH" ;; esac
  VENDOR_ROOT="$SUITE_DIR/build-$ARCH"
  rm -rf "$VENDOR_ROOT"
  mkdir -p "$VENDOR_ROOT/bin" "$VENDOR_ROOT/lib" "$VENDOR_ROOT/share/repoman"

  install -m 0755 "$scriptsdir/yum-via-lrm.sh" "$VENDOR_ROOT/bin/yum-via-lrm.sh"
  install -m 0755 "$scriptsdir/install-lrm-tools.sh" "$VENDOR_ROOT/bin/install-lrm-tools.sh" 2>/dev/null || true
  install -m 0755 "$scriptsdir/install-net-tools.sh" "$VENDOR_ROOT/bin/install-net-tools.sh"
  install -m 0755 "$scriptsdir/configrepo.sh" "$VENDOR_ROOT/bin/configrepo.sh"
  if [[ -x /home/docker/iso-sources/ROOT/configrepo ]]; then
    install -m 0755 /home/docker/iso-sources/ROOT/configrepo "$VENDOR_ROOT/bin/configrepo"
  elif [[ -x "$scriptsdir/configrepo" ]]; then
    install -m 0755 "$scriptsdir/configrepo" "$VENDOR_ROOT/bin/configrepo"
  fi

  cat >"$VENDOR_ROOT/bin/getbar" <<'EOF'
#!/bin/sh
echo "getbar: stub (centos ${CENTOS_STUB:-5/6} — fixed HTTP vault mirrors; no bwsel)" >&2
exit 0
EOF
  chmod 0755 "$VENDOR_ROOT/bin/getbar"

  cat >"$VENDOR_ROOT/bin/lrm" <<EOF
#!/bin/sh
echo "lrm stub ${FAMILY}/${SUITE} (fixed vault mirrors; bwsel disabled)" >&2
echo "lrm 0.0.0-stub"
exit 0
EOF
  chmod 0755 "$VENDOR_ROOT/bin/lrm"

  printf '# stub repoman share for %s/%s\n' "$FAMILY" "$SUITE" \
    >"$VENDOR_ROOT/share/repoman/README.stub"

  log "build-$ARCH ready (stub): $VENDOR_ROOT"
  find "$VENDOR_ROOT" -type f | sed 's|^|  |'
done
