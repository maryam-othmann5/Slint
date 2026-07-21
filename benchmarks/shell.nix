# Nix shell providing the system libraries Slint's Rust/C++ crates need at
# build time (via pkg-config) and run time (dynamic linking), for NixOS or
# any Nix user. Not needed on distros where these ship as normal dev packages
# (e.g. `apt install libfontconfig1-dev` on Debian/Ubuntu).
#
# Usage:
#   nix-shell benchmarks/shell.nix
#   cd rust/slint-markup-app && cargo run --release
#
# Covers: Rust benchmarks, the C++ benchmark (cmake/gcc + same libs), and
# the Python benchmark's native `slint` wheel, which links the same
# windowing/graphics libraries at import time.

{ pkgs ? import <nixpkgs> {} }:

let
  libs = with pkgs; [
    fontconfig
    freetype
    expat
    libxkbcommon
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    libGL
    vulkan-loader
  ];
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    pkg-config
    cmake
    gcc
    python3
    python3Packages.pip
    python3Packages.virtualenv
  ] ++ libs;

  # Needed at *build* time so pkg-config finds fontconfig.pc etc.
  PKG_CONFIG_PATH = pkgs.lib.makeSearchPath "lib/pkgconfig" libs;

  # Needed at *run* time so the compiled binaries can dlopen X11/Wayland/GL.
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath libs;

  shellHook = ''
    echo "Slint benchmark shell ready (fontconfig, pkg-config, X11/Wayland/GL libs on PATH)."
  '';
}
