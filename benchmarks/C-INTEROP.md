# Using Slint from plain C

**Short answer: there is no official C binding.** Slint officially supports Rust, C++, JavaScript/TypeScript, and Python (see `docs/CASE-STUDY.md` §1.2). If you came here wanting a `slint-counter-c/` folder like the other three languages, this doc explains why that folder doesn't exist and what your real options are — that's more useful than a demo that pretends support exists.

## Why there's no first-class C binding

Slint's C++ API itself is generated on top of a Rust `#[repr(C)]` FFI layer via `cbindgen` (see §1.2 of the case study) — but the *public* API that ships is the ergonomic C++ layer (classes, RAII, templates) built on top of that raw C-ABI, not the raw C-ABI itself. The raw layer is an internal implementation detail, not a supported/stable public interface.

## Your real options if you need to call Slint from C

**Option A — write a thin C wrapper around the C++ API (recommended).**
This is the standard "how do I call C++ from C" pattern, and it's the only correct way to do this — extern "C" bridges are a well-understood pattern for exactly this reason.

```cpp
// slint_c_bridge.cpp — compiled as part of your C++ build
#include "app.h"   // generated from app.slint, same as benchmarks/cpp

extern "C" {

// Opaque handle so C code never sees the C++ type directly.
struct SlintAppHandle;

SlintAppHandle* slint_app_create() {
    auto ui = new slint::ComponentHandle<AppWindow>(AppWindow::create());
    return reinterpret_cast<SlintAppHandle*>(ui);
}

void slint_app_run(SlintAppHandle* handle) {
    auto* ui = reinterpret_cast<slint::ComponentHandle<AppWindow>*>(handle);
    (*ui)->run();
}

void slint_app_destroy(SlintAppHandle* handle) {
    delete reinterpret_cast<slint::ComponentHandle<AppWindow>*>(handle);
}

} // extern "C"
```

```c
/* main.c — your actual C application */
#include "slint_c_bridge.h"

int main(void) {
    SlintAppHandle *app = slint_app_create();
    slint_app_run(app);
    slint_app_destroy(app);
    return 0;
}
```

You compile `slint_c_bridge.cpp` with a C++ compiler and link it into your otherwise-C project — this is exactly how large C codebases have historically wrapped C++ libraries (Qt bindings for C did this for years). It's real work, not a hack, but it is work you'd own and maintain yourself; the project doesn't ship or test this path for you.

**Option B — don't use Slint from C at all.**
If your project is genuinely plain C (not C mixed with some C++), it's worth being honest that Slint is not the toolkit built for that use case. Depending on what you need, GTK (native C API), Dear ImGui (has C bindings via `cimgui`), or Nuklear (single-header, pure C) are more natural fits — worth a look before investing in a hand-rolled bridge layer.

## If you're not sure yet whether you're "really" a C project

If your codebase is C but you're allowed to add a `.cpp` file and link a C++ standard library, Option A is genuinely low-risk and well-trodden — most large "C" codebases already do this for one dependency or another. If you're on a constrained embedded target where you can't take on a C++ toolchain at all, that's a harder constraint worth raising directly — happy to think through it with the specifics of your target.
