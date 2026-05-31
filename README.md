# pyrealsense2-extended

Pre-built [Intel RealSense SDK 2.0](https://github.com/IntelRealSense/librealsense) Python wheels for all platforms — including **Linux aarch64 (Jetson)** Python versions that upstream `pyrealsense2` does not publish on PyPI.

There is no source code in this repo. It downloads official wheels from PyPI (`pyrealsense2`) and adds aarch64 builds via cibuildwheel for the gaps. All wheels are renamed to `pyrealsense2-extended` and uploaded to PyPI under a unified version.

## Install

```sh
pip install pyrealsense2-extended
```

Drop-in replacement — just `import pyrealsense2` as usual.

## Platform Coverage

Upstream `pyrealsense2` publishes aarch64 wheels only for cp39, cp310, and cp312. This package fills in the rest:

| | Linux x86_64 | Linux aarch64 | Windows x86_64 |
|---|---|---|---|
| Python 3.9 | ✅ upstream | ✅ upstream | ✅ upstream |
| Python 3.10 | ✅ upstream | ✅ upstream | ✅ upstream |
| Python 3.11 | ✅ upstream | ✅ **built here** | ✅ upstream |
| Python 3.12 | ✅ upstream | ✅ upstream | ✅ upstream |
| Python 3.13 | ✅ upstream | ✅ **built here** | ✅ upstream |
| Python 3.14 | ✅ upstream | ✅ **built here** | ✅ upstream |

The aarch64 wheels are manylinux2014-compatible (works on Ubuntu 20.04+, Jetson L4T 35+).

## Building & Publishing

See [PUBLISHING.md](PUBLISHING.md).

## Upstream

This is a community republish of [IntelRealSense/librealsense](https://github.com/IntelRealSense/librealsense). All credit for the actual SDK goes to the Intel RealSense team. Licensed under Apache-2.0, same as upstream.
