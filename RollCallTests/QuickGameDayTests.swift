import XCTest
@testable import RollCall

final class QuickGameDayTests: XCTestCase {
    @MainActor
    func testControlDestinationIntentQueuesSystemControlRequest() async throws {
        let center = OpenGameDayRequestCenter.shared
        if let pendingRequest = center.pendingRequest {
            center.consume(id: pendingRequest.id)
        }

        defer {
            if let pendingRequest = center.pendingRequest {
                center.consume(id: pendingRequest.id)
            }
        }

        _ = try await OpenGameDayFromControlIntent().perform()

        XCTAssertNil(center.pendingRequest?.explicitTeamID)
        XCTAssertEqual(center.pendingRequest?.source, .systemControl)
    }

    func testTelemetrySourceUsesOnlyReliablyKnownSystemPath() {
        XCTAssertEqual(QuickGameDayInvocationSource.appIntent.telemetryValue, "appIntent")
        XCTAssertEqual(QuickGameDayInvocationSource.systemControl.telemetryValue, "systemControl")
        XCTAssertEqual(QuickGameDayInvocationSource.unknownSystem.telemetryValue, "unknownSystem")
    }

    func testRememberedGameDayTeamWinsOverSelectedTeam() {
        var viewed = RollCallTestFixtures.team()
        viewed.id = UUID()
        viewed.name = "Viewed"
        var played = RollCallTestFixtures.team()
        played.id = UUID()
        played.name = "Played"
        let state = state(teams: [viewed, played], selected: viewed.id, remembered: played.id)

        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(source: .unknownSystem), in: state),
            .gameDay(teamID: played.id, targetKind: .rememberedTeam)
        )
    }

    func testExplicitTeamOverridesRememberedTeam() {
        var remembered = RollCallTestFixtures.team()
        remembered.id = UUID()
        remembered.name = "Remembered"
        var explicit = RollCallTestFixtures.team()
        explicit.id = UUID()
        explicit.name = "Explicit"
        let state = state(teams: [remembered, explicit], selected: remembered.id, remembered: remembered.id)

        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(explicitTeamID: explicit.id, source: .appIntent), in: state),
            .gameDay(teamID: explicit.id, targetKind: .explicitTeam)
        )
    }

    func testMissingRememberedTeamFallsBackWithoutChoosingAnotherTeam() {
        var existing = RollCallTestFixtures.team()
        existing.id = UUID()
        existing.name = "Existing"
        let state = state(teams: [existing], selected: existing.id, remembered: UUID())

        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(source: .unknownSystem), in: state),
            .fallback(.rememberedTeamMissing)
        )
    }

    func testNoRememberedTeamAndNoTeamsHaveDistinctExpectedFallbacks() {
        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(source: .unknownSystem), in: state(teams: [], selected: nil, remembered: nil)),
            .fallback(.noTeams)
        )
        let team = RollCallTestFixtures.team()
        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(source: .unknownSystem), in: state(teams: [team], selected: team.id, remembered: nil)),
            .fallback(.noRememberedTeam)
        )
    }

    func testDeletedExplicitTeamFallsBackEvenWhenRememberedTeamExists() {
        let remembered = RollCallTestFixtures.team()
        let state = state(teams: [remembered], selected: remembered.id, remembered: remembered.id)

        XCTAssertEqual(
            OpenGameDayResolver.resolve(OpenGameDayRequest(explicitTeamID: UUID(), source: .appIntent), in: state),
            .fallback(.explicitTeamMissing)
        )
    }

    func testGameDayURLRoundTripsOptionalTeam() throws {
        let teamID = UUID()
        XCTAssertEqual(URL.rollCallOpenGameDay(teamID: teamID).rollCallOpenGameDayTarget, .explicitTeam(teamID))
        XCTAssertEqual(URL.rollCallOpenGameDay().rollCallOpenGameDayTarget, .rememberedTeam)
        XCTAssertNil(URL(string: "https://example.com")!.rollCallOpenGameDayTarget)
        XCTAssertNil(URL(string: "rollcall://game-day?team=not-a-uuid")!.rollCallOpenGameDayTarget)
    }

    private func state(teams: [Team], selected: UUID?, remembered: UUID?) -> AppState {
        var state = AppState.empty
        state.teams = teams
        state.selectedTeamID = selected
        state.lastGameDayTeamID = remembered
        return state
    }
}
