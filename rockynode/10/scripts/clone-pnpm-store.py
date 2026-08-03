#!/usr/bin/env python3
"""Clone a lockfile-subset of a pnpm v3 CAFS store (for Docker bake).

Reads package integrities from pnpm-lock.yaml, copies package -index.json
entries and referenced file blobs (including -exec variants) into dest.
Skips optional native packages for non-linux-x64 platforms.
"""
from __future__ import annotations

import argparse
import base64
import json
import re
import shutil
import sys
from pathlib import Path

SKIP_SUBSTR = (
    "darwin",
    "win32",
    "android",
    "freebsd",
    "sunos",
    "openbsd",
    "netbsd",
    "linux-arm",
    "linux-ppc",
    "linux-riscv",
    "linux-s390",
    "linuxmusl",
    "aix-",
    "openharmony",
)

PKG_RE = re.compile(
    r"(?m)^  ('?@?[^'@\n]+@[^:\n]+'?):\n"
    r"    resolution: \{integrity: (sha512-[A-Za-z0-9+/=]+)\}"
)


def ssri_hex(ssri: str) -> str:
    return base64.b64decode(ssri.split("-", 1)[1]).hex()


def should_skip(name: str) -> bool:
    low = name.lower().strip("'")
    if "linux-x64" in low or "linuxmusl-x64" in low:
        return False
    return any(s in low for s in SKIP_SUBSTR)


def resolve_file(src_files: Path, fh: str, mode: int | None) -> Path | None:
    names: list[str] = []
    if mode is not None and (mode & 0o100):
        names.append(f"{fh[2:]}-exec")
    names.extend([fh[2:], f"{fh[2:]}-exec"])
    for name in names:
        cand = src_files / fh[:2] / name
        if cand.exists():
            return cand
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lockfile", required=True, type=Path)
    ap.add_argument("--src-store", required=True, type=Path, help="…/store/v3")
    ap.add_argument("--dst-store", required=True, type=Path, help="…/pnpm-store (parent; writes v3/)")
    args = ap.parse_args()

    src_root = args.src_store
    if (src_root / "v3").is_dir():
        src_root = src_root / "v3"
    src_files = src_root / "files"
    if not src_files.is_dir():
        print(f"error: missing CAFS files at {src_files}", file=sys.stderr)
        return 1

    dst_parent = args.dst_store
    dst_root = dst_parent / "v3"
    if dst_parent.exists():
        shutil.rmtree(dst_parent)
    (dst_root / "files").mkdir(parents=True)

    idx_db = src_root / "index.db"
    if idx_db.exists():
        shutil.copy2(idx_db, dst_root / "index.db")

    pkgs = PKG_RE.findall(args.lockfile.read_text())
    copied_idx = copied_files = miss_idx = miss_files = skipped = 0

    for name, ssri in pkgs:
        if should_skip(name):
            skipped += 1
            continue
        hx = ssri_hex(ssri)
        src_idx = src_files / hx[:2] / f"{hx[2:]}-index.json"
        if not src_idx.exists():
            miss_idx += 1
            print(f"MISS idx {name}", file=sys.stderr)
            continue
        dst_idx = dst_root / "files" / hx[:2] / f"{hx[2:]}-index.json"
        dst_idx.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_idx, dst_idx)
        copied_idx += 1
        meta = json.loads(src_idx.read_text())
        for _rel, info in (meta.get("files") or {}).items():
            fi = info["integrity"]
            mode = info.get("mode")
            fh = ssri_hex(fi)
            fsrc = resolve_file(src_files, fh, mode)
            if fsrc is None:
                miss_files += 1
                print(f"MISS file {name} {_rel}", file=sys.stderr)
                continue
            fdst = dst_root / "files" / fh[:2] / fsrc.name
            fdst.parent.mkdir(parents=True, exist_ok=True)
            if not fdst.exists():
                shutil.copy2(fsrc, fdst)
                copied_files += 1

    print(
        f"clone-pnpm-store: indexes={copied_idx} files={copied_files} "
        f"skipped_platform={skipped} miss_idx={miss_idx} miss_files={miss_files}"
    )
    if miss_idx or miss_files:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
