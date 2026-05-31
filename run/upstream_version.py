#!/usr/bin/env python3
"""Single source of truth for the upstream pyrealsense2 version.

Queries PyPI for the latest pyrealsense2 release so our republished
pyrealsense2-extended automatically tracks upstream instead of pinning a
hardcoded version. Importable (build/rename use the functions) and runnable.

Usage:
    upstream_version.py            # upstream version, e.g. 2.58.1.10581
    upstream_version.py --tag      # librealsense git tag, e.g. v2.58.1
    upstream_version.py --target   # our dist version, e.g. 2.58.1.10581.post1

Env overrides (for pinning / reproducibility):
    UPSTREAM_VERSION   pin the upstream version instead of querying PyPI
    POST_RELEASE       post-release number for --target (default 1)
"""

import json
import os
import sys
import urllib.request

UPSTREAM_PACKAGE = "pyrealsense2"


def upstream_version():
    pinned = os.environ.get("UPSTREAM_VERSION")
    if pinned:
        return pinned
    url = f"https://pypi.org/pypi/{UPSTREAM_PACKAGE}/json"
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)["info"]["version"]


def git_tag(version=None):
    version = version or upstream_version()
    return "v" + ".".join(version.split(".")[:3])


def target_version(version=None):
    version = version or upstream_version()
    post = os.environ.get("POST_RELEASE", "1")
    return f"{version}.post{post}"


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    version = upstream_version()
    if arg == "--tag":
        print(git_tag(version))
    elif arg == "--target":
        print(target_version(version))
    elif arg in ("", "--version"):
        print(version)
    else:
        print(f"Unknown argument: {arg}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
