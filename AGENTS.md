# pyrealsense2-extended — Agent Context

## What This Repo Does

Republishes pyrealsense2 Python wheels under the name `pyrealsense2-extended`, **filling the Linux aarch64 (Jetson) gaps** for Python versions that upstream doesn't cover on PyPI.

Pattern mirrors `~/repos/cyclonedds_extended` (cyclonedds-extended). No source code in this repo — it downloads upstream PyPI wheels for platforms that already have them, builds aarch64 manylinux wheels via cibuildwheel for missing versions, renames everything to `pyrealsense2_extended`, twine-uploads.

## Upstream

- Repo: https://github.com/IntelRealSense/librealsense
- Tracks PyPI package: `pyrealsense2`
- Currently mirrored: 2.58.1.10581
- Build system upstream: cmake + setuptools (Python wrapper under wrappers/python/)

The C++ library (librealsense2) is cmake-built first, then the Python wrapper builds against it.

## Platform Coverage

| Platform | Source |
|---|---|
| Linux x86_64 cp39-cp314 | upstream PyPI |
| Linux aarch64 cp39, cp310, cp312 | upstream PyPI |
| **Linux aarch64 cp311, cp313, cp314** | **built here via cibuildwheel** |
| Windows x86_64 cp310-cp314 | upstream PyPI |

No macOS wheels exist upstream or here.

## Build Commands

```bash
./run/build              # build missing aarch64 python versions (cp311, cp313, cp314)
./run/build cp311        # one python version
./run/download_wheels    # download upstream + collect local
./run/rename_wheels      # rename to pyrealsense2_extended
./run/publish            # full pipeline + twine upload

# Nix (local dev / non-manylinux wheels)
nix build .#pyrealsense2-wheel-cp312
nix develop              # dev shell with all build deps
```

## How the Build Works

librealsense's Python bindings are NOT a standalone Python package. The build flow is:

1. **cmake** builds the C++ library (librealsense2.so) + pybind11 Python extensions (.so)
2. **find_librs_version.py** reads `RS2_API_*_VERSION` macros from `rs.h` → generates `_version.py`
3. Built `.so` files + `_version.py` are copied into `wrappers/python/pyrealsense2/`
4. **hatchling** (via `python -m build`) packages everything into a wheel
5. **auditwheel** bundles shared libs into the wheel for manylinux portability

`run/build` handles all of this inside a `manylinux2014_aarch64` Docker container.

## Files

| File | Purpose |
|---|---|
| `pyproject.toml` | Package metadata for the wrapper (name=pyrealsense2-extended) |
| `pyrealsense2_extended/__init__.py` | Stub package; the actual `pyrealsense2` import lives in the wheel payload |
| `download_wheels.py` | Pulls latest `pyrealsense2` wheels from PyPI |
| `rename_wheel.py` | Rewrites wheel filename + dist-info METADATA to `pyrealsense2_extended` |
| `run/build` | Docker-based manylinux aarch64 wheel builder |
| `run/publish` | End-to-end pipeline |
| `flake.nix` | Nix-based build (for local dev; not manylinux-tagged) |

## Likely Pitfalls

1. **Renaming wheels does not change `import` name** — by design. The wheel still installs the `pyrealsense2` package, so `import pyrealsense2` works.

2. **librealsense build is cmake-based, not pure Python** — the cmake step must run from the repo root with `-DBUILD_PYTHON_BINDINGS=ON`. The `wrappers/python/pyproject.toml` (hatchling) only packages pre-built .so files, it does NOT compile anything.

3. **_version.py is generated** — `find_librs_version.py` reads version macros from `include/librealsense2/rs.h`. It's in `.gitignore` upstream. Must be generated before `python -m build`.

4. **FORCE_RSUSB_BACKEND** — set in the build to avoid needing kernel drivers in the container. The rsusb backend uses libusb directly.

5. **auditwheel is required** — the built .so links against librealsense2.so and libusb. auditwheel bundles these into the wheel so it's self-contained.

6. **Version sync** — when bumping upstream, update `pyproject.toml` `version`, `pyrealsense2_extended/__init__.py` `__version__`, `UPSTREAM_TAG` and `UPSTREAM_VERSION` in `run/build`, and `librealsenseVersion` in `flake.nix`.
