# Case Study: Slint — Architecture, Method Efficiency, and How It Compares

*Last updated: July 2026*

## 1. What Slint is

[Slint](https://slint.dev) is an open-source, declarative GUI toolkit for building native user interfaces in Rust, C++, JavaScript, or Python, targeting desktop, embedded/MCU, mobile, and web (via WebAssembly) from one codebase. The name is a backronym for the project's design goals: **S**calable, **L**ightweight, **I**ntuitive, **N**ative, **T**ooled.

Two things distinguish it from most of the Rust GUI field:

1. **A dedicated declarative markup language (`.slint`)** compiled ahead-of-time into native code for the target language, rather than a purely code-driven or macro-driven UI definition.
2. **A genuine embedded/MCU focus.** The runtime is designed to fit in a very small memory footprint and run without a heap allocator or dynamic memory in constrained configurations, which is unusual among Rust GUI projects that mostly target desktop first.

### 1.1 Architecture at a glance

Slint's stack has four layers:

- **Language bindings** — Rust, C++, Node.js, and Python APIs sit on top of the core.
- **Compiler** — the `.slint` compiler runs the typical phases (lexing, parsing, optimization, code generation) and emits code for the target language: a Rust module, a C++ header, or bytecode for the interpreter. Because `.slint` expressions are pure, the compiler can inline constant properties and optimize dead code at compile time.
- **Core runtime** — a reactive property engine and an "item tree" that lays components, elements, and properties out in a single contiguous memory region to minimize allocations at runtime.
- **Rendering & platform backends** — pluggable renderers and windowing backends selected at compile time (see §3).

### 1.2 How the multi-language mechanism actually works

This is the part most intros skip, and it's worth understanding because it explains *why* Slint can promise "one `.slint` file, four languages" without secretly maintaining four separate UI engines.

**The core is Rust, full stop.** `i-slint-core` (the item tree, the reactive property engine, event dispatch) and `i-slint-compiler` (the `.slint` lexer/parser/optimizer/codegen) are both Rust crates. Every other language is a *binding on top of that one core* — there is no independent C++ or Python implementation of the rendering/property engine to keep in sync.

**Correction worth flagging explicitly:** Slint officially supports **Rust, C++, JavaScript/TypeScript, and Python** — there is no first-class **plain C** binding. If you need to call Slint from C, the practical path is writing a thin `extern "C"` wrapper around the C++ API yourself; it's not something the project ships or supports out of the box.

Per language, the mechanism looks like this:

| Language | How it reaches the Rust core |
|---|---|
| **Rust** | Native — no FFI boundary at all. `slint-build`/`slint!` generate ordinary Rust code that calls `i-slint-core` directly. This is the "reference" binding; every other language is built to match its behavior. |
| **C++** | Semi-automatic binding generation: Rust functions marked `#[repr(C)]` in an internal `ffi` module are turned into a C-ABI layer by `cbindgen`, which emits C/C++ headers. A hand-written, ergonomic C++ API (classes, RAII, templates) sits on top of that raw C-ABI layer so application code never touches the unsafe FFI directly. The `.slint` compiler emits a matching C++ header per component. |
| **JavaScript / TypeScript (Node.js)** | A native Node.js addon wraps the Rust core (N-API-style bindings), and the compiler emits a JS-idiomatic API per `.slint` component. Because Node's event loop and Slint's own event loop are different beasts, the binding has to explicitly integrate the two — Slint's team has publicly documented fixing a bug where the UI thread woke up every 16 ms even while idle, burning CPU/battery, which is a good illustration that "just bind the core" isn't actually free — the integration layer has real correctness and efficiency work of its own. |
| **Python** | Same idea: a native extension module wraps the Rust core and exposes an idiomatic Python API generated from the same compiled `.slint` component. |

**Why this matters for efficiency:** the compiler and runtime optimizations described in §1.1 and §2 (constant inlining, single-memory-region item tree, AOT compilation) happen **once, in Rust, in the shared core** — they are not reimplemented per language and don't degrade based on which language you call Slint from. What *does* vary by language is the FFI/binding overhead at the boundary (a C++ call across the `cbindgen`-generated C-ABI layer, or a Python call across the native extension boundary) and, for Node.js/Python specifically, the cost of keeping two event loops or two memory-management models coherent. In practice this overhead is small relative to rendering cost, but it's not literally zero, and it's the reason the Node.js binding needed its own dedicated fix rather than "just working" once the Rust core was fast.

### 1.3 Licensing

Slint uses a dual/triple licensing model: a GPLv3 option for open-source use, a royalty-free permissive license for desktop/mobile/web development, and a paid perpetual-fallback license with commercial support. This is worth checking against your project's needs before committing — it's more restrictive than the permissive MIT/Apache-2.0 licenses most pure-Rust GUI crates use (egui, Iced) or Tauri's MIT license.

---

## 2. Method comparison #1: three ways to build UI in Slint

This is the comparison most existing write-ups skip, and it's the one that actually matters day-to-day once you've chosen Slint.

| Method | How it works | Compile-time cost | Runtime cost | Best for |
|---|---|---|---|---|
| **External `.slint` file (AOT)** | UI described in a separate `.slint` file, compiled ahead-of-time by `slint-build` in `build.rs`, pulled in via `slint::include_modules!()` | Adds a build-script compilation pass; slightly longer `cargo build`, but only on change | Lowest — properties, bindings, and layout are resolved and optimized at compile time; item tree is laid out once in a single memory block | The default choice for almost all production apps. Best tooling (LSP, live-preview, VS Code extension), designers can edit the `.slint` file independently |
| **Inline `slint!` macro** | The same `.slint` DSL, written directly inside a Rust source file and expanded by a procedural macro at compile time — still AOT-compiled, just no separate file | Compiled as part of the normal `cargo build` (proc-macro expansion), no external build script needed | Same as the external-file path — it goes through the same compiler, just invoked differently | Small UIs, quick prototypes, or single-file examples where a separate `.slint` file feels like overkill |
| **Interpreter** | `.slint` source is parsed and evaluated at *runtime* rather than compiled ahead-of-time | None (no build step) | Highest — parsing + tree construction happens every run, no compile-time inlining/optimization | Tooling only: the live-preview, the LSP server, and SlintPad (the browser-based playground) use this. **Not recommended for production apps** |

**Practical takeaway:** the external-file and inline-macro paths go through the same AOT compiler and have essentially identical runtime efficiency — the choice is purely about project organization (separate design file + live-preview support vs. single-file convenience). The interpreter is meaningfully slower at startup since parsing and tree construction happen on every run instead of once at compile time, which is why it's reserved for tooling rather than shipped apps.

---

## 3. Method comparison #2: rendering backends

This is the lever with the biggest real-world efficiency impact, especially on embedded targets, and it's chosen at **compile time** via Cargo features.

| Backend | Rendering approach | Dependencies | Typical use case | Efficiency notes |
|---|---|---|---|---|
| **FemtoVG** | GPU-accelerated, targets OpenGL ES 2.0 | Needs an OpenGL ES 2.0-capable GPU/driver | Default for most desktop and Linux embedded targets with GPU acceleration | Good balance of quality and resource use; the long-standing default |
| **Skia** | GPU-accelerated (or CPU fallback), via Google's Skia graphics library | Pulls in the Skia dependency (larger binary, longer compile) | Apps that want Skia's broader feature set / text shaping quality, or need consistency with other Skia-based tooling | Larger binary and build time cost than FemtoVG; strongest rendering fidelity |
| **Software renderer** | Pure CPU rasterization, no GPU dependency at all | None beyond Slint core | Microcontrollers and embedded Linux devices without a GPU, or where a GPU driver stack is undesirable | Smallest dependency footprint and smallest binary; trades peak rendering performance for portability and near-zero-dependency builds — this is how Slint hits sub-megabyte RAM targets on MCUs |
| **Qt backend (optional)** | Delegates widget rendering to Qt's `QStyle` when Qt is installed on the system | Requires a system Qt install | Apps that must look 100% native on desktop platforms where Qt is already present | Not relevant to embedded; adds a heavyweight optional dependency for native look-and-feel |

On embedded/MCU targets, Slint also automatically picks between GPU-accelerated, DMA2D, full-framebuffer, or line-by-line partial-rendering strategies depending on what the hardware exposes, which is part of how the project claims a sub-300 KiB RAM runtime footprint on constrained devices.

**Practical takeaway:** default to FemtoVG on desktop unless you have a specific reason not to. Switch to the Software renderer for MCU/embedded targets or anywhere you cannot assume a GPU driver stack. Reach for Skia only if you need its specific rendering/text features and can absorb the larger binary.

---

## 4. Slint vs. other Rust GUI approaches

| Framework | UI paradigm | Native widgets? | Approx. idle memory | Approx. binary size | Mobile support | License |
|---|---|---|---|---|---|---|
| **Slint** | Declarative DSL (AOT-compiled) or Rust builder, retained-mode | Yes (own widget set, optional Qt style) | Low — designed for embedded | Small–moderate; grows with chosen renderer (Skia > FemtoVG > Software) | Yes (iOS/Android), actively maturing | GPL / royalty-free / commercial |
| **egui / eframe** | Immediate-mode, macro-free Rust | No (draws its own look, not OS-native) | Low | Small | Limited/experimental | MIT/Apache-2.0 |
| **Tauri** | Web frontend (HTML/CSS/JS) + Rust backend, via the OS's system WebView | Native via OS WebView, not native widgets | Low–moderate (uses system WebView, not a bundled browser) | Very small installers, since no browser engine is bundled | Yes | MIT |
| **GTK4-rs** | Retained-mode bindings to GTK4 | Yes, fully native on Linux; less native elsewhere | Moderate | Depends on system GTK (usually already installed) | No | MIT (bindings); GTK itself LGPL |
| **Iced** | Elm-inspired retained-mode, pure Rust | No (custom rendering) | Low–moderate | Small–moderate | Experimental | MIT |
| **Dioxus** | React-like component model, multi-renderer (web/desktop/mobile) | Depends on renderer target | Varies by renderer | Varies | Yes | MIT/Apache-2.0 |

A few qualitative points worth calling out from recent practitioner write-ups rather than vendor pages:

- A 2026 survey of the Rust GUI ecosystem found that of the libraries surveyed, the large majority weren't yet "production-ready" by the survey's bar (build/setup failures, missing tested features, or being outdated) — Slint, Dioxus, egui, Floem, and Xilem stood out for having comparatively straightforward, low-boilerplate APIs, with Slint's DSL and egui's macro-free approach singled out for developer experience.
- Accessibility (screen reader support) across the Rust GUI ecosystem is generally immature; Slint's basic assistive-tech infrastructure currently depends on the optional Qt backend rather than being renderer-independent.
- Tauri's efficiency case rests on *not* bundling a browser engine — real-world measurements commonly cited put Tauri idle memory around 30–40 MB and installers in the 3–15 MB range, versus Electron's 300–500 MB idle memory and 100+ MB installers — which is a different efficiency axis than Slint's (Tauri is optimizing "web tech but without the browser tax"; Slint is optimizing "no web tech, no browser, no GC, runs on an MCU").

**Practical takeaway:** the honest framing isn't "Slint is faster than X" — it's that each project optimizes for a different constraint:

- Choose **Slint** when you want one codebase spanning desktop → embedded → MCU, native-feeling widgets, and you're fine with either its DSL or its license terms.
- Choose **egui** when you want the simplest possible immediate-mode API and don't need OS-native widget look.
- Choose **Tauri** when your team already has web frontend skills/code and wants a small installer without writing a native UI at all.
- Choose **GTK4-rs** or a Qt-backed toolkit when you need deep desktop-native integration on Linux specifically and don't care about embedded targets.

---

## 5. How to actually measure this yourself

Vendor claims and blog posts (including this one) should not be the end of the story. This repo ships **the same minimal counter app built in Rust (two ways), C++, and Python** under [`../benchmarks`](../benchmarks), plus a doc explaining the real options for C (there is no official C binding — see [`../benchmarks/C-INTEROP.md`](../benchmarks/C-INTEROP.md)). Between them you can measure:

- Cold build/compile time per language
- Final binary size (Rust, C++ — Python doesn't produce a comparable single binary; see its README for what to measure instead)
- Peak RSS during a short idle run (via `/usr/bin/time -v` on Linux)

See [`../benchmarks/README.md`](../benchmarks/README.md) for exact steps per language. Numbers vary by OS, compiler/interpreter version, and chosen renderer backend, which is exactly why this repo gives you a harness instead of a single hard-coded table.

---

## 5a. Which language should *you* actually build in?

This is the part that matters most if you're evaluating Slint for a real desktop app at work, and it doesn't have a single right answer — it depends on what you're optimizing for.

| Your situation | Recommendation | Why |
|---|---|---|
| **You (or your team) already write Rust**, or are free to pick any language for a new project | **Rust** | You get the reference implementation with the fewest FFI layers between your code and Slint's core (see §1.2) — no `cbindgen`-generated boundary, no interpreter overhead. Best tooling, most examples, first to get new features. |
| **You're in an existing C++ codebase/team**, evaluating whether to add Slint for a new UI surface | **C++** | Full AOT compilation, native performance, and it integrates into a normal CMake build. The cost is the FFI boundary and a heavier initial build (Slint's Rust core compiles as part of your CMake build the first time — see `benchmarks/cpp/slint-counter-cpp/README.md`). Worth it if your team isn't going to adopt Rust just for the UI layer. |
| **You're in an existing Python codebase** (data tooling, internal apps, scripting-heavy team) | **Python** | Lets a Python team ship a real native-feeling desktop UI without learning Rust or C++ at all. The honest cost: no AOT compilation (UI is parsed at runtime — see `benchmarks/python/slint-counter-py/README.md`), and higher idle memory since you're carrying a full Python interpreter. Fine for internal tools and most business apps; think twice for something latency- or resource-critical. |
| **You're in a plain C codebase** | **Reconsider, or write a thin C++ wrapper** | There's no official C binding. See [`benchmarks/C-INTEROP.md`](../benchmarks/C-INTEROP.md) for the real wrapper pattern if you're stuck with Slint specifically, or for other C-native toolkits worth considering instead. |
| **You're new to GUI development and just want to learn** | **Start with Rust, using the external `.slint` file method** | It's the path with the best docs, the live-preview tooling, and the fewest moving parts to debug when something doesn't work. Once you're comfortable, cross-reference the C++ or Python version of the same counter app in this repo to see how the *same* `.slint` file plugs into a different language — that comparison is often more illuminating than reading either language's docs in isolation. |
| **You're evaluating Slint for work and need to justify the choice to others** | **Build the same small internal tool in your team's primary language first** | Don't evaluate Slint in the abstract — the benchmarks in this repo are a starting point, not a substitute. Time-box a real (small) feature in your actual codebase's language, using this repo's equivalent app as a reference, and measure build integration pain, not just runtime numbers. |

---

## 6. Limitations and honest caveats

- Slint's licensing is more complex than a single permissive license — check the GPL/royalty-free/commercial terms against your project before adopting it.
- Mobile support (iOS/Android) is newer and less battle-tested than desktop/embedded support.
- Accessibility tooling is currently strongest only when the optional Qt backend is available.
- The Rust GUI ecosystem as a whole is young; API churn between minor versions is more likely than in Qt or GTK, which have decades of stability behind them.

## 7. References

- Slint official site — https://slint.dev
- Slint architecture overview (DeepWiki) — https://deepwiki.com/slint-ui/slint
- "Rust and C++ Interoperability" (Slint Blog — binding generation mechanism) — https://slint.dev/blog/rust-and-cpp
- "Slint and the Node.js Event Loop" (Slint Blog) — https://slint.dev/blog/slint-and-the-nodejs-event-loop
- "The State of Rust GUI – The Good and Bad" — https://weeklyrust.substack.com/p/the-state-of-rust-gui-the-good-and
- "The state of Rust GUI libraries" (LogRocket) — https://blog.logrocket.com/state-rust-gui-libraries/
- "Tauri vs. Electron" (DEV Community) — https://dev.to/raftlabs/tauri-vs-electron-23d1
- "Typst Studio Desktop: 90% Smaller, 100% Native..." (Tauri efficiency figures) — https://dev.to/rerere_l_f165d08cdc06148/typst-studio-desktop-90-smaller-100-native-same-wasm-codebase-with-tauri-3len
