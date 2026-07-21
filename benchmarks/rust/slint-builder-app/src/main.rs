// Minimal Slint app built with the inline `slint!` macro — same DSL and same
// AOT compiler as ../slint-markup-app, just embedded directly in this file
// instead of a separate ui/app.slint. Compare build time/binary size against
// ../slint-markup-app to see the practical cost/benefit of each authoring
// method (see docs/CASE-STUDY.md, section 2).

slint::slint! {
    import { Button } from "std-widgets.slint";

    export component AppWindow inherits Window {
        width: 300px;
        height: 150px;
        title: "Slint Builder-API Benchmark";

        in-out property <int> counter: 0;
        callback increment();

        VerticalLayout {
            alignment: center;
            spacing: 12px;

            Text {
                text: "Counter: " + counter;
                horizontal-alignment: center;
                font-size: 20px;
            }

            Button {
                text: "Increment";
                clicked => { increment(); }
            }
        }
    }
}

fn main() -> Result<(), slint::PlatformError> {
    let ui = AppWindow::new()?;

    let ui_handle = ui.as_weak();
    ui.on_increment(move || {
        let ui = ui_handle.unwrap();
        ui.set_counter(ui.get_counter() + 1);
    });

    ui.run()
}
