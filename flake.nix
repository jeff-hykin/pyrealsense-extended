{
  description = "Build pyrealsense2 Python wheels for Linux aarch64";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        librealsenseVersion = "2.58.1";
        librealsenseTag = "v${librealsenseVersion}";
        # Update this hash after first build attempt (nix will tell you the correct one)
        librealsenseSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

        pythonVersions = {
          "311" = pkgs.python311;
          "312" = pkgs.python312;
          "313" = pkgs.python313;
        };

        librealsense-src = pkgs.fetchFromGitHub {
          owner = "IntelRealSense";
          repo = "librealsense";
          rev = librealsenseTag;
          sha256 = librealsenseSha256;
        };

        commonCmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DBUILD_EXAMPLES=OFF"
          "-DBUILD_GRAPHICAL_EXAMPLES=OFF"
          "-DFORCE_RSUSB_BACKEND=ON"
          "-DBUILD_SHARED_LIBS=ON"
          "-DBUILD_LEGACY_PYBACKEND=OFF"
        ];

        # C++ library (shared across Python versions)
        librealsense-cpp = pkgs.stdenv.mkDerivation {
          pname = "librealsense2";
          version = librealsenseVersion;
          src = librealsense-src;

          nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
          buildInputs = [ pkgs.libusb1 pkgs.udev ];

          cmakeFlags = commonCmakeFlags ++ [
            "-DBUILD_PYTHON_BINDINGS=OFF"
          ];

          meta = with pkgs.lib; {
            description = "Intel RealSense SDK 2.0";
            homepage = "https://github.com/IntelRealSense/librealsense";
            license = licenses.asl20;
          };
        };

        # Build a wheel for a specific Python version
        mkWheel = pyVer: python:
          let
            pythonPackages = python.pkgs;
          in
          pkgs.stdenv.mkDerivation {
            pname = "pyrealsense2-wheel-cp${pyVer}";
            version = librealsenseVersion;
            src = librealsense-src;

            nativeBuildInputs = [
              pkgs.cmake
              pkgs.pkg-config
              python
              pythonPackages.hatchling
              pythonPackages.build
              pythonPackages.pybind11
            ];

            buildInputs = [
              librealsense-cpp
              pkgs.libusb1
              pkgs.udev
            ];

            cmakeFlags = commonCmakeFlags ++ [
              "-DBUILD_PYTHON_BINDINGS=ON"
              "-DPYTHON_EXECUTABLE=${python}/bin/python"
            ];

            buildPhase = ''
              make -j$NIX_BUILD_CORES
            '';

            installPhase = ''
              runHook preInstall

              # Generate _version.py
              ${python}/bin/python $src/wrappers/python/find_librs_version.py $src $src/wrappers/python/pyrealsense2 || {
                # If find_librs_version.py fails (read-only src), generate manually
                echo "__version__ = \"${librealsenseVersion}\"" > wrappers/python/pyrealsense2/_version.py 2>/dev/null || true
              }

              # Copy .so files to the Python package source tree
              WRAPPER_DIR=$(mktemp -d)
              cp -r $src/wrappers/python/* "$WRAPPER_DIR/"
              chmod -R u+w "$WRAPPER_DIR"

              # Generate _version.py in our writable copy
              echo "__version__ = \"${librealsenseVersion}\"" > "$WRAPPER_DIR/pyrealsense2/_version.py"

              # Copy built .so files
              find . -name "pyrealsense2*.so" -exec cp {} "$WRAPPER_DIR/pyrealsense2/" \;
              find . -name "pyrsutils*.so" -exec cp {} "$WRAPPER_DIR/pyrealsense2/" \;

              # Build the wheel
              cd "$WRAPPER_DIR"
              ${python}/bin/python -m build --wheel --outdir $out

              echo ""
              echo "=== Output wheel ==="
              ls -lh $out/*.whl

              runHook postInstall
            '';

            dontFixup = true;
          };

        wheelPackages = builtins.mapAttrs (ver: python:
          mkWheel ver python
        ) pythonVersions;

        defaultPython = pythonVersions."312";
        defaultPythonPackages = defaultPython.pkgs;

        # Python with the tools the publish pipeline needs (so `python3 -m twine`
        # works). download_wheels.py / rename_wheel.py use only the stdlib.
        publishPython = defaultPython.withPackages (ps: [ ps.twine ps.build ]);

        # The single reproducible publish command. Wraps run/publish with a
        # pinned python+twine so `nix run .#publish` is identical locally and in CI.
        publishApp = pkgs.writeShellApplication {
          name = "publish";
          runtimeInputs = [ publishPython pkgs.git ];
          text = builtins.readFile ./run/publish;
        };

      in {
        packages = {
          librealsense-cpp = librealsense-cpp;

          pyrealsense2-wheel-cp311 = wheelPackages."311";
          pyrealsense2-wheel-cp312 = wheelPackages."312";
          pyrealsense2-wheel-cp313 = wheelPackages."313";

          pyrealsense2-wheel = wheelPackages."312";
          default = wheelPackages."312";
        };

        apps.publish = {
          type = "app";
          program = "${publishApp}/bin/publish";
        };
        apps.default = self.apps.${system}.publish;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.cmake
            pkgs.pkg-config
            pkgs.libusb1
            defaultPython
            defaultPythonPackages.pybind11
            defaultPythonPackages.hatchling
            defaultPythonPackages.build
            defaultPythonPackages.twine
          ];

          shellHook = ''
            echo "pyrealsense2 build shell (upstream: ${librealsenseVersion})"
            echo "  cmake, libusb, python ${defaultPython.pythonVersion} available"
            echo ""
            echo "Build targets:"
            echo "  nix build                              # cp312 (default)"
            echo "  nix build .#pyrealsense2-wheel-cp311"
            echo "  nix build .#pyrealsense2-wheel-cp312"
            echo "  nix build .#pyrealsense2-wheel-cp313"
            echo ""
            echo "Docker build (for manylinux wheels):"
            echo "  ./run/build          # cp311 cp313 cp314"
            echo "  ./run/build cp311    # single version"
          '';
        };
      }
    );
}
