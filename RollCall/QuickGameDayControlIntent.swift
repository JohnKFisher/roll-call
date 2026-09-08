import AppIntents
import Combine
import Foundation

enum QuickGameDayInvocationSource: String, Codable, Sendable {
    case appIntent
    case systemControl
    case unknownSystem
    case inApp

    var telemetryValue: String {
        switch self {
        case .appIntent:
            return "appIntent"
        case .systemControl:
            return "systemControl"
        case .unknownSystem:
            return "unknownSystem"
        case .inApp:
            return "inApp"
        }
    }
}

struct OpenGameDayRequest: Equatable, Sendable {
    let id: UUID
    let explicitTeamID: UUID?
    let source: QuickGameDayInvocationSource

    init(
        id: UUID = UUID(),
        explicitTeamID: UUID? = nil,
        source: QuickGameDayInvocationSource
    ) {
        self.id = id
        self.explicitTeamID = explicitTeamID
        self.source = source
    }
}

@MainActor
final class OpenGameDayRequestCenter: ObservableObject {
    static let shared = OpenGameDayRequestCenter()
    @Published private(set) var pendingRequest: OpenGameDayRequest?

    private init() {}

    func submit(_ request: OpenGameDayRequest) {
        pendingRequest = request
    }

    func consume(id: UUID) {
        guard pendingRequest?.id == id else { return }
        pendingRequest = nil
    }
}

struct OpenGameDayControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Game Day"
    static let description = IntentDescription("Open Roll Call directly to Game Day without starting playback.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenGameDayFromControlIntent())
    }
}

struct OpenGameDayFromControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Game Day"
    static let description = IntentDescription("Open Roll Call directly to Game Day without starting playback.")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        OpenGameDayRequestCenter.shared.submit(
            OpenGameDayRequest(source: .systemControl)
        )
        return .result()
    }
}
