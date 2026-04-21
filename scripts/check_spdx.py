#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
"""Verify staged source files carry SPDX-License-Identifier and Copyright lines."""
import sys

REQUIRED = ["SPDX-License-Identifier:", "Copyright"]


def check(path):
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            head = f.read(2048)
    except OSError as e:
        return [str(e)]
    return [r for r in REQUIRED if r not in head]


errors = []
for path in sys.argv[1:]:
    missing = check(path)
    if missing:
        errors.append(f"{path}: missing {', '.join(missing)}")

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
