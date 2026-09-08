import SwiftUI
import WidgetKit

struct QuickGameDayControl: ControlWidget {
    static let kind = "com.jkfisher.rollcall.quick-game-day"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenGameDayControlIntent()) {
                Label {
                    Text("Open Game Day")
                } icon: {
                    Image("ControlCenterIcon")
                        .renderingMode(.template)
                }
            }
        }
        .displayName("Quick Game Day")
        .description("Open the most recently used Roll Call team in Game Day.")
    }
}

@main
struct RollCallControlsBundle: WidgetBundle {
    var body: some Widget {
        QuickGameDayControl()
    }
}
