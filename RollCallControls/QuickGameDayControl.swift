import AppIntents
import SwiftUI
import WidgetKit

struct OpenGameDayControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Game Day"
    static let description = IntentDescription("Open Roll Call directly to Game Day without starting playback.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "rollcall://game-day")!))
    }
}

struct QuickGameDayControl: ControlWidget {
    static let kind = "com.jkfisher.rollcall.quick-game-day"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenGameDayControlIntent()) {
                Label("Open Game Day", systemImage: "play.rectangle.fill")
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
