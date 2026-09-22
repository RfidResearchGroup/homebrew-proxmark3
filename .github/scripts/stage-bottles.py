#!/usr/bin/env python3
"""Validate merged bottle metadata and stage archives using their release names."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


def filename(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+@-]*\.tar\.gz", value):
        raise ValueError(f"Invalid bottle filename: {value!r}")
    return value


def stage(bottle_dir, output_dir):
    if bottle_dir.is_symlink() or not bottle_dir.is_dir():
        raise ValueError("Bottle directory must be a real directory")
    if output_dir.is_symlink() or (output_dir.exists() and
            (not output_dir.is_dir() or any(output_dir.iterdir()))):
        raise ValueError("Output directory must be absent or empty, and not a symlink")
    metadata = sorted(bottle_dir.glob("*.bottle.json"))
    if not metadata:
        raise ValueError("No bottle metadata found")
    planned = {}
    for path in metadata:
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Metadata must be a regular file: {path.name}")
        formulas = json.loads(path.read_text())
        if not isinstance(formulas, dict) or not formulas:
            raise ValueError(f"Empty or invalid bottle metadata: {path.name}")
        for formula in formulas.values():
            tags = formula["bottle"]["tags"]
            if not isinstance(tags, dict) or not tags:
                raise ValueError(f"Empty or invalid bottle tags: {path.name}")
            for tag in tags.values():
                source = bottle_dir / filename(tag["local_filename"])
                destination = filename(tag["filename"])
                expected = tag["sha256"]
                if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
                    raise ValueError(f"Invalid SHA256 for {source.name}")
                if source.is_symlink() or not source.is_file():
                    raise ValueError(f"Missing or non-regular bottle: {source.name}")
                digest = hashlib.sha256()
                with source.open("rb") as archive:
                    while chunk := archive.read(1024 * 1024):
                        digest.update(chunk)
                if digest.hexdigest() != expected:
                    raise ValueError(f"SHA256 mismatch for {source.name}")
                if destination in planned and planned[destination][1] != expected:
                    raise ValueError(f"Conflicting bottle contents for {destination}")
                planned[destination] = (source, expected)
    if not planned:
        raise ValueError("No bottle archives to stage")
    # Do not create or populate the output until every input has been checked.
    output_dir.mkdir(parents=True, exist_ok=True)
    for destination, (source, _) in planned.items():
        shutil.copyfile(source, output_dir / destination)
    return len(planned)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bottle_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    try:
        count = stage(args.bottle_dir, args.output_dir)
    except (ValueError, KeyError, TypeError, OSError) as error:
        raise SystemExit(str(error)) from error
    print(f"Staged {count} bottle archives in {args.output_dir}")
