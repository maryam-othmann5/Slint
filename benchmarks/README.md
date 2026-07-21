# Benchmarks

The same tiny app — a counter with an increment button — built in every language Slint officially supports, so you can compare them directly instead of trusting a table.

| Language | Path | Method |
|---|---|---|
| **Rust** | [`rust/slint-markup-app`](rust/slint-markup-app) | External `.slint` file, AOT-compiled via `build.rs` |
| **Rust** | [`rust/slint-builder-app`](rust/slint-builder-app) | Inline `slint!` macro, same AOT compiler |
| **C++** | [`cpp/slint-counter-cpp`](cpp/slint-counter-cpp) | External `.slint` file, AOT-compiled via CMake's `slint_target_sources` |
| **Python** | [`python/slint-counter-py`](python/slint-counter-py) | External `.slint` file, **interpreted at runtime** (no AOT step — see its README for why that's a real trade-off, not a footnote) |
| **C** | [`C-INTEROP.md`](C-INTEROP.md) | Not officially supported — this doc explains why and shows the real wrapper pattern instead of pretending a demo app exists |

## Quick start per language

```bash
# Rust
cd rust/slint-markup-app && cargo run --release

# C++
cd cpp/slint-counter-cpp && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build && ./build/slint_counter_cpp

# Python
cd python/slint-counter-py && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && python main.py
```

Each language's own README has full prerequisites and troubleshooting.

## Using Nix / NixOS

Slint's Rust/C++ builds need `fontconfig` and a few windowing/graphics libraries (X11/Wayland, OpenGL) available via `pkg-config` at build time and dynamic linking at run time. On most distros these come from a dev package (`apt install libfontconfig1-dev`); on NixOS they need to be declared explicitly. A ready-made shell is provided:

```bash
nix-shell benchmarks/shell.nix
# then, inside that shell:
cd rust/slint-markup-app && cargo run --release
```

This covers the Rust, C++, and Python benchmarks — all three ultimately link the same underlying windowing/graphics libraries.

## Measuring things yourself

- **Rust**: `rust/measure.sh` — cold build time + stripped binary size for both Rust variants.
- **C++**: see the "Measuring build time / binary size" section in `cpp/slint-counter-cpp/README.md`.
- **Python**: see the "What to actually compare" section in `python/slint-counter-py/README.md` — binary size isn't a meaningful metric here; startup time and idle memory are.

Numbers vary by OS, compiler/interpreter version, and chosen renderer backend. Run each measurement 2–3 times and look at the trend, not a single number.

## Trying a different Slint rendering backend (Rust/C++)

Slint's rendering backend is chosen via feature flags at compile time. To force the CPU-only Software renderer (useful on headless CI, or to approximate the embedded-target numbers discussed in `../docs/CASE-STUDY.md`):

```toml
# Rust: Cargo.toml
slint = { version = "1.16", default-features = false, features = ["backend-winit", "renderer-software"] }
```

See the [Slint docs](https://slint.dev) for the current, authoritative list of feature flags for both Rust and CMake — they occasionally change between minor versions.
