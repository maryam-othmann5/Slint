# Slint counter — Python

Same app as the Rust and C++ versions: a counter with an increment button. Unlike those, this one is **not** ahead-of-time compiled — the Python binding loads and interprets `app.slint` via `slint-interpreter` (see `docs/CASE-STUDY.md` §1.2). That's a real, measurable trade-off, not just an implementation detail — see "What to actually compare" below.

## Prerequisites

- Python >= 3.9
- pip (or uv — Slint's own docs recommend `uv add slint`)

## Setup & run

```bash
cd slint-counter-py
python -m venv .venv
source .venv/bin/activate      # .venv\Scripts\activate on Windows
pip install -r requirements.txt
python main.py
```

## What to actually compare

Don't compare a "binary size" here the way you would for Rust/C++ — there isn't one; you're shipping a `.py` file plus a Python interpreter plus the native `slint` extension wheel. The comparisons that are actually meaningful for Python are:

- **Cold startup time** (`time python main.py`, closing the window immediately) — this includes parsing `app.slint` at runtime, which the Rust/C++ versions don't pay because they compiled it ahead of time.
- **Idle memory** (`/usr/bin/time -v python main.py` → `Maximum resident set size`) — includes the Python interpreter itself, which is a fixed cost the Rust/C++ binaries don't have at all.
- **Distribution story** — you're shipping source + a venv (or a `pyinstaller`/`pyoxidizer`-style bundle) rather than a single stripped native binary, which matters if "how do I ship this to a non-technical user" is part of your evaluation.

These are the numbers to weigh against the Rust (`../../rust/measure.sh`) and C++ (`../slint-counter-cpp/README.md`) results if you're deciding which language to actually build a desktop app in — see `docs/CASE-STUDY.md` for the fuller decision guide.
