# Unlike the Rust and C++ versions, this UI is loaded and interpreted at
# import time rather than compiled ahead-of-time into generated code — see
# docs/CASE-STUDY.md section 1.2 for why the Python binding works this way
# (it wraps slint-interpreter via PyO3, not the AOT compiler path).

import slint


# `slint.loader.app` looks for app.slint on sys.path — since main.py and
# app.slint live in the same directory, running `python main.py` from this
# folder is enough for it to be found automatically.
class App(slint.loader.app.AppWindow):
    @slint.callback
    def increment(self):
        self.counter = self.counter + 1


def main():
    app = App()
    app.run()


if __name__ == "__main__":
    main()
