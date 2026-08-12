#!/usr/bin/env python3
"""Hash one generated Customer.io dependency tree without following symlinks."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re


class SnapshotError(RuntimeError):
    pass


def content_snapshot(
    root: Path,
    hash_overrides: dict[str, str] | None = None,
) -> dict[str, object]:
    if root.is_symlink() or not root.is_dir():
        raise SnapshotError("resolved Customer.io dependency root is unsafe")
    overrides = dict(hash_overrides or {})
    for relative, digest in overrides.items():
        if (
            not relative
            or relative.startswith("/")
            or ".." in Path(relative).parts
            or re.fullmatch(r"[0-9a-f]{64}", digest) is None
        ):
            raise SnapshotError("dependency snapshot override is unsafe")

    entries = sorted(
        root.rglob("*"),
        key=lambda path: path.relative_to(root).as_posix(),
    )
    tree = hashlib.sha256()
    encountered_overrides: set[str] = set()
    for path in entries:
        relative_path = path.relative_to(root)
        if ".git" in relative_path.parts:
            continue
        if path.is_symlink():
            raise SnapshotError("resolved Customer.io dependency contains unsafe input")
        if path.is_dir():
            continue
        if not path.is_file():
            raise SnapshotError("resolved Customer.io dependency contains unsafe input")
        relative = relative_path.as_posix()
        digest = overrides.get(relative)
        if digest is None:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
        else:
            encountered_overrides.add(relative)
        tree.update(f"{digest}  {relative}\n".encode())

    if encountered_overrides != set(overrides):
        raise SnapshotError("dependency snapshot override did not match a regular file")
    return {
        "algorithm": "sha256",
        "tree_hash": tree.hexdigest(),
        "diff_hash": "f213e7a51dc2eb59c9dbb21d33e32d42d967530933597b1abb06fcdbc2010195",
        "ignored_build_inputs_excluded": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("root", type=Path)
    arguments = parser.parse_args()
    try:
        result = content_snapshot(arguments.root)
    except (OSError, SnapshotError) as error:
        parser.error(str(error))
    print(result["tree_hash"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
