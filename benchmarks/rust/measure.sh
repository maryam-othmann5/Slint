#!/usr/bin/env bash
# Measures cold release-build time and final stripped binary size for both
# Rust benchmark apps. Run from the benchmarks/rust/ directory.
# (For C++ and Python builds, see ../cpp/slint-counter-cpp/README.md and
# ../python/slint-counter-py/README.md instead — their build systems don't
# produce comparable "one binary" artifacts the same way Cargo does.)
#
# Usage: ./measure.sh
#
# Notes:
#   - Requires a Rust toolchain (cargo) and, on Linux, a windowing environment
#     for Slint's default backend to build/link cleanly.
#   - Uses `cargo clean` before each build to get a genuine cold-build time;
#     comment that out if you want incremental-build numbers instead.

set -euo pipefail

APPS=("slint-markup-app" "slint-builder-app")

for app in "${APPS[@]}"; do
  echo "== $app =="
  pushd "$app" > /dev/null

  cargo clean

  start=$(date +%s)
  cargo build --release
  end=$(date +%s)

  bin_path="target/release/$app"
  if [ -f "$bin_path" ]; then
    size=$(du -h "$bin_path" | cut -f1)
  else
    size="unknown (check target/release/ for the binary name)"
  fi

  echo "  Cold release build time: $((end - start))s"
  echo "  Stripped binary size:    $size"
  echo

  popd > /dev/null
done

echo "Done. For peak memory (RSS), run e.g.:"
echo "  /usr/bin/time -v ./slint-markup-app/target/release/slint-markup-app"
echo "and check 'Maximum resident set size'. Requires the 'time' package (not the shell builtin) on Linux."
