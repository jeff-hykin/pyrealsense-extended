#!/usr/bin/env python3
"""
Download existing pyrealsense2 wheels from PyPI and collect locally-built ones.

Populates wheels_input/ with all wheels that will be renamed and uploaded
as pyrealsense2-extended.

Sources:
  - PyPI: pyrealsense2 (various platforms/versions)
  - Local: wheelhouse/*.whl (cibuildwheel-built aarch64 wheels for missing versions)
"""

import json
import shutil
import urllib.request
from pathlib import Path

PYPI_PACKAGE = "pyrealsense2"

# Optional substring filter — set to e.g. ["cp312", "cp313"] to limit. [] = no filter.
PYTHON_VERSION_FILTER: list[str] = []

# We build ALL Linux aarch64 wheels ourselves (manylinux2014, glibc 2.17) so they
# run on Jetsons. Upstream aarch64 wheels are skipped: some require glibc 2.34/2.38
# which Jetsons (glibc 2.31) don't have. Matches the tag substring in filenames.
SKIP_UPSTREAM_TAGS = ["aarch64"]

OUTPUT_DIR = Path("wheels_input")


def get_pypi_info(package_name):
    url = f"https://pypi.org/pypi/{package_name}/json"
    print(f"Fetching {url} ...")
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def download_file(url, dest):
    print(f"  Downloading {dest.name} ...", end=" ", flush=True)
    urllib.request.urlretrieve(url, dest)
    size_mb = dest.stat().st_size / (1024 * 1024)
    print(f"({size_mb:.1f} MB)")


def download_pypi_wheels(package_name, output_dir):
    info = get_pypi_info(package_name)
    version = info["info"]["version"]
    print(f"\nLatest {package_name} version: {version}")

    files = info["releases"].get(version, [])
    wheels = [f for f in files if f["filename"].endswith(".whl")]

    if not wheels:
        print(f"  No wheels found for {package_name} {version}")
        return []

    print(f"  Found {len(wheels)} wheel(s)")

    downloaded = []
    for whl in wheels:
        filename = whl["filename"]

        if PYTHON_VERSION_FILTER:
            if not any(pv in filename for pv in PYTHON_VERSION_FILTER):
                print(f"  Skipping {filename} (filtered)")
                continue

        dest = output_dir / filename
        if dest.exists():
            print(f"  Already exists: {filename}")
        else:
            download_file(whl["url"], dest)
        downloaded.append(dest)

    return downloaded


def collect_local_wheels(output_dir):
    """Copy locally-built aarch64 wheels from wheelhouse/ into the output directory."""
    wheelhouse = Path("wheelhouse")
    local_wheels = list(wheelhouse.glob("*.whl")) if wheelhouse.exists() else []

    if not local_wheels:
        print("\nNo local aarch64 wheels found in wheelhouse/ (run ./run/build to create them)")
        return []

    print(f"\nFound {len(local_wheels)} local wheel(s) in wheelhouse/")
    collected = []
    for whl in local_wheels:
        dest = output_dir / whl.name
        if dest.exists():
            dest.chmod(0o644)
            dest.unlink()
        shutil.copy2(whl, dest)
        dest.chmod(0o644)
        size_mb = dest.stat().st_size / (1024 * 1024)
        print(f"  Copied {whl.name} ({size_mb:.1f} MB)")
        collected.append(dest)

    return collected


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    all_wheels = []

    print("=" * 60)
    print(f"Downloading wheels from PyPI ({PYPI_PACKAGE})")
    print("=" * 60)
    all_wheels.extend(download_pypi_wheels(PYPI_PACKAGE, OUTPUT_DIR))

    print("\n" + "=" * 60)
    print("Collecting locally-built wheels (aarch64)")
    print("=" * 60)
    all_wheels.extend(collect_local_wheels(OUTPUT_DIR))

    print("\n" + "=" * 60)
    print(f"Total: {len(all_wheels)} wheel(s) in {OUTPUT_DIR}/")
    print("=" * 60)
    for whl in sorted(OUTPUT_DIR.glob("*.whl")):
        size_mb = whl.stat().st_size / (1024 * 1024)
        print(f"  {whl.name}  ({size_mb:.1f} MB)")

    if all_wheels:
        print(f"\nNext step: ./run/rename_wheels")


if __name__ == "__main__":
    main()
