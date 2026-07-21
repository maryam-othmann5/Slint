// Generated from ui/app.slint by the CMake slint_target_sources() call
// (ahead-of-time, same compiler as the Rust build — see docs/CASE-STUDY.md §1.2).
#include "app.h"

int main()
{
    auto ui = AppWindow::create();

    // Use a weak handle in the callback so the callback doesn't keep the
    // window alive forever via a reference cycle (ui owns the callback,
    // the callback would otherwise own a strong reference back to ui).
    ui->on_increment([weak = slint::ComponentWeakHandle(ui)] {
        if (auto locked = weak.lock()) {
            auto &ui = *locked;
            ui->set_counter(ui->get_counter() + 1);
        }
    });

    ui->run();
}
