# Slint UI Toolkit — A Practical Case Study

> An in-depth look at [Slint](https://slint.dev), the Rust-native declarative GUI toolkit — its architecture, its internal method trade-offs (`.slint` markup vs. Rust builder API vs. interpreter), its rendering backends, and how it stacks up against other Rust GUI options (egui, Tauri, GTK4-rs, Iced, Dioxus).

## Why this repo exists

Rust's GUI ecosystem is fragmented and moves fast. Most comparisons online are either marketing pages or one-off "I built the same app three times" blog posts with no reproducible numbers. This repo tries to be the thing I wished existed: a written case study **plus** runnable, minimal benchmark projects so you can verify the claims yourself instead of trusting a table on the internet.

## Contents

| Path | What's in it |
|---|---|
| [`docs/CASE-STUDY.md`](docs/CASE-STUDY.md) | The full write-up: architecture, multi-language mechanism, method comparison, renderer comparison, competitor comparison, and **a decision guide for which language to actually build in** (§5a) |
| [`benchmarks/`](benchmarks/) | The *same* minimal counter app built in **Rust** (two ways), **C++**, and **Python** — plus an honest doc on why there's no C version (there's no official C binding) |
| [`benchmarks/README.md`](benchmarks/README.md) | How to run every language's version and what to measure |

## TL;DR

- **Slint** is a declarative, AOT-compiled GUI toolkit for Rust/C++/JS/Python, designed for a small memory footprint (runtime fits in well under 1 MiB RAM on embedded targets) and for scaling from microcontrollers to desktop.
- **The core engine is Rust-only.** C++, JavaScript/TypeScript, and Python are all bindings generated on top of that one Rust core (via `cbindgen`-generated C-ABI layers for C++, native addons for Node.js/Python) — not separate reimplementations. There is **no official plain-C binding**, only C++. See §1.2 of the case study for exactly how each language reaches the core, and where the real per-language overhead lives.
- Inside Slint, you have **three ways to build UI**: an external `.slint` file compiled ahead-of-time via `build.rs` (recommended default), the inline `slint!` macro (same DSL, same AOT compiler, just embedded directly in a `.rs` file), and the **interpreter** (parses `.slint` at runtime — used by tools like the live-preview and SlintPad, not recommended for production apps due to interpretation overhead).
- Slint ships **three interchangeable rendering backends** (FemtoVG/OpenGL ES2, Skia, and a dependency-free CPU Software renderer), chosen at compile time — this is the single biggest lever for efficiency on embedded/low-power targets.
- Compared to competitors: Slint trades the raw immediate-mode simplicity of **egui** for a heavier but more "application-shaped" retained-mode model with native-feeling widgets; it trades **Tauri**'s web-tech flexibility for a smaller, all-Rust dependency chain and no WebView; and it trades **GTK4/Qt**'s maturity for a much smaller footprint and first-class embedded/MCU support.
- **Not sure which language to actually build in?** See the decision table in §5a of the case study — it's tailored to "I already write X" and "I'm evaluating this for work" rather than a generic feature list.

Full detail, sources, and the "when should I actually use this" guidance are in [`docs/CASE-STUDY.md`](docs/CASE-STUDY.md).

## Quick start (try Slint yourself)

Pick your language and jump straight to a runnable example:

```bash
# Rust
cd benchmarks/rust/slint-markup-app && cargo run --release

# C++
cd benchmarks/cpp/slint-counter-cpp && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build && ./build/slint_counter_cpp

# Python
cd benchmarks/python/slint-counter-py && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && python main.py
```

Full prerequisites and troubleshooting per language are in [`benchmarks/README.md`](benchmarks/README.md). If you need C specifically, read [`benchmarks/C-INTEROP.md`](benchmarks/C-INTEROP.md) first — it explains why there's no demo app for it.

## Pushing this to your own GitHub

This folder is a plain, un-initialized repo. To publish it:

```bash
cd slint-case-study
git init
git add .
git commit -m "Add Slint case study"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

(Create the empty repo on GitHub first, or use `gh repo create <name> --public --source=. --push` if you have the GitHub CLI installed.)

## License

MIT — see [`LICENSE`](LICENSE). Adjust to taste before publishing.

## Contributing

Corrections and additional real-world benchmark numbers (especially on embedded/MCU targets) are welcome — open a PR or an issue.
# Slint
