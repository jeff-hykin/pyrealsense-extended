# Publishing to PyPI

This package uploads pyrealsense2 wheels to PyPI under the distribution name `pyrealsense2-extended`.

## What Gets Uploaded

Wheels from two sources, all renamed to `pyrealsense2_extended` with a normalized version:

**From PyPI (`pyrealsense2`):**
- cp39-cp314 × manylinux1 x86_64
- cp39/cp310/cp312 × manylinux2014 aarch64
- cp310-cp314 × win_amd64

**Built locally (`wheelhouse/`):**
- cp311/cp313/cp314 × manylinux2014 aarch64 — no upstream wheels exist

Each wheel:
- Contains the `pyrealsense2` package (so `import pyrealsense2` works)
- Has distribution name `pyrealsense2-extended` (avoids conflict with official `pyrealsense2`)
- Version normalized to match `pyproject.toml` so PyPI accepts the batch

## Quick Publish

```bash
./run/publish
```

## Manual Steps

```bash
# 1. Build aarch64 wheels (run on a Jetson, or Linux ARM box, or Mac+Docker)
./run/build

# 2. Download upstream wheels + collect local aarch64 builds
./run/download_wheels

# 3. Rename all to pyrealsense2_extended
./run/rename_wheels

# 4. Validate
twine check renamed_wheels/*.whl

# 5. Upload
twine upload renamed_wheels/*.whl
```

## Where to run the aarch64 build

`./run/build` invokes cibuildwheel. Three options:

| Where | Speed | Notes |
|---|---|---|
| **Native Linux aarch64** (Jetson, Ampere) | Fast | Just install Docker + Python, run `./run/build` |
| **GitHub Actions** `ubuntu-22.04-arm` runner | Fast | Free for public repos |
| **macOS / Linux x86_64 with Docker + qemu** | Slow (10-30×) | `docker run --privileged --rm tonistiigi/binfmt --install arm64` first |

## Version Bumping

1. Update `version` in `pyproject.toml` (e.g., `2.58.1.10581.post2`) and in `pyrealsense2_extended/__init__.py`
2. Update `UPSTREAM_TAG` in `run/build` if upstream has a new release
3. Publish: `./run/publish`

The rename script reads the version from `pyproject.toml` and normalizes all wheels to that version.
