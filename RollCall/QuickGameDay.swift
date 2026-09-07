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

enum QuickGameDayTargetKind: String, Codable, Sendable {
    case explicitTeam
    case rememberedTeam
}

enum QuickGameDayFallbackReason: String, Codable, Sendable {
    case noRememberedTeam
    case rememberedTeamMissing
    case explicitTeamMissing
    case noTeams
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

enum OpenGameDayResolution: Equatable, Sendable {
    case gameDay(teamID: UUID, targetKind: QuickGameDayTargetKind)
    case fallback(QuickGameDayFallbackReason)
}

enum OpenGameDayResolver {
    static func resolve(_ request: OpenGameDayRequest, in state: AppState) -> OpenGameDayResolution {
        if let explicitTeamID = request.explicitTeamID {
            guard state.teams.contains(where: { $0.id == explicitTeamID }) else {
                return .fallback(.explicitTeamMissing)
            }
            return .gameDay(teamID: explicitTeamID, targetKind: .explicitTeam)
        }

        guard let rememberedTeamID = state.lastGameDayTeamID else {
            return .fallback(state.teams.isEmpty ? .noTeams : .noRememberedTeam)
        }
        guard state.teams.contains(where: { $0.id == rememberedTeamID }) else {
            return .fallback(.rememberedTeamMissing)
        }
        return .gameDay(teamID: rememberedTeamID, targetKind: .rememberedTeam)
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

extension URL {
    enum RollCallGameDayTarget: Equatable {
        case rememberedTeam
        case explicitTeam(UUID)
    }

    static func rollCallOpenGameDay(teamID: UUID? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "rollcall"
        components.host = "game-day"
        if let teamID {
            components.queryItems = [URLQueryItem(name: "team", value: teamID.uuidString)]
        }
        return components.url!
    }

    var rollCallOpenGameDayTarget: RollCallGameDayTarget? {
        guard scheme?.lowercased() == "rollcall", host?.lowercased() == "game-day" else { return nil }
        let teamItem = URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "team" })
        guard let teamItem else { return .rememberedTeam }
        guard let value = teamItem.value,
              let teamID = UUID(uuidString: value) else { return nil }
        return .explicitTeam(teamID)
    }
}

struct GameDayTeamEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Roll Call Team")
    static let defaultQuery = GameDayTeamEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GameDayTeamEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [GameDayTeamEntity] {
        loadTeams().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [GameDayTeamEntity] {
        loadTeams()
    }

    private func loadTeams() -> [GameDayTeamEntity] {
        guard let url = try? AppPaths.stateURL(),
              let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(AppState.self, from: data) else { return [] }
        return state.teams.map { GameDayTeamEntity(id: $0.id, name: $0.name) }
    }
}

struct OpenGameDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Game Day"
    static let description = IntentDescription("Open Roll Call directly to Game Day without starting playback.")
    static let openAppWhenRun = true

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Team", description: "Optional. Leave blank to use the team most recently opened in Game Day.")
    var team: GameDayTeamEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        OpenGameDayRequestCenter.shared.submit(
            OpenGameDayRequest(explicitTeamID: team?.id, source: .appIntent)
        )
        return .result()
    }
}

struct RollCallAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenGameDayIntent(),
            phrases: [
                "Open Game Day in \(.applicationName)",
                "Start Game Day in \(.applicationName)"
            ],
            shortTitle: "Open Game Day",
            systemImageName: "play.rectangle.fill"
        )
    }
}
