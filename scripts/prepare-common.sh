#!/bin/bash
# Copy shared files from scripts/ into a suite's etc/ before docker build.
#
# Usage: prepare-common.sh FAMILY/SUITE
#        prepare-common.sh --all
#
# Generated suite paths (gitignored):
#   <suite>/etc/bash_alias  ← scripts/bash_alias

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAMILIES=(centos rocky debian ubuntu sles openeuler)

die() { printf 'prepare-common: error: %s\n' "$*" >&2; exit 1; }

prepare_suite() {
  local spec=$1
  local suite_dir="$ROOT/$spec"
  local etc="$suite_dir/etc"

  [[ -d "$suite_dir" ]] || die "missing suite dir $suite_dir"
  [[ -d "$etc" ]] || die "missing $etc"

  mkdir -p "$etc"
  cp -f "$ROOT/scripts/bash_alias" "$etc/bash_alias"
}

if [[ $# -lt 1 ]]; then
  die "usage: prepare-common.sh FAMILY/SUITE | --all"
fi

if [[ "$1" == "--all" ]]; then
  for fam in "${FAMILIES[@]}"; do
    for df in "$ROOT/$fam"/*/Dockerfile; do
      [[ -f "$df" ]] || continue
      prepare_suite "$fam/$(basename "$(dirname "$df")")"
    done
  done
  exit 0
fi

prepare_suite "$1"
