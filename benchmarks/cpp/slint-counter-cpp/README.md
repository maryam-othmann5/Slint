# Slint counter — C++

Same app as the Rust versions in `../../rust/`: a counter with an increment button. Built via the C++ AOT path (`slint_target_sources` in CMake compiles `ui/app.slint` into a generated `app.h`).

## Prerequisites

- CMake >= 3.21
- A C++20 compiler (GCC, Clang, or MSVC)
- Rust toolchain (Slint's C++ API is built via [Corrosion](https://github.com/corrosion-rs/corrosion) on top of the Rust core — see `docs/CASE-STUDY.md` §1.2 — so `cargo`/`rustc` need to be on your `PATH` even though you're writing C++)

## Build & run

```bash
cd slint-counter-cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
./build/slint_counter_cpp        # or build/Release/slint_counter_cpp.exe on Windows
```

The first build will take a while — `FetchContent` downloads and compiles the Slint C++/Rust core itself. Subsequent builds are fast.

## Measuring build time / binary size

```bash
rm -rf build
time (cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release)
du -h build/slint_counter_cpp
```

Compare against the Rust numbers from `../../rust/measure.sh` — this is the concrete way to see the FFI-layer overhead discussed in `docs/CASE-STUDY.md` §1.2 in practice (small in absolute terms, but the C++ build/link story is noticeably heavier than Rust's single-crate `cargo build`, mostly due to compiling the Slint core itself as part of your build the first time).
