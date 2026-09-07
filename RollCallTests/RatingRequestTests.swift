import XCTest
@testable import RollCall

@MainActor
final class RatingRequestTests: XCTestCase {
    private var temp: RollCallTemporaryDirectory!

    override func setUpWithError() throws {
        temp = try RollCallTemporaryDirectory()
        AppPaths.testBaseDirectoryOverride = temp.fileURL("AppSupport")
    }

    override func tearDownWithError() throws {
        AppPaths.testBaseDirectoryOverride = nil
        temp = nil
    }

    private func coordinator(
        isAppStoreBuild: Bool = true,
        now: Date
    ) -> RollCallTelemetryCoordinator {
        let provider = RecordingTelemetryProvider()
        let store = TelemetryStore(url: temp.fileURL("telemetry.json"), now: now)
        let context = TelemetryBuildContext(
            isAppStoreBuild: isAppStoreBuild,
            isTestFlightBuild: !isAppStoreBuild,
            isDeveloperBuild: !isAppStoreBuild,
            isSwiftUIPreview: false
        )
        let preference = AnonymousUsageAnalyticsPreference(
            defaults: UserDefaults(suiteName: "RatingRequestTests")!
        )
        return RollCallTelemetryCoordinator(
            provider: provider,
            store: store,
            preference: preference,
            buildContext: context
        )
    }

    func testAutomaticOpportunitiesUseProbableGameDatesAndConfirmedAppearance() {
        let enrollment = Date(timeIntervalSince1970: 1_000_000)
        let firstDate = enrollment.addingTimeInterval(7 * 86_400)
        let secondDate = firstDate.addingTimeInterval(86_400)
        let coordinator = coordinator(now: enrollment)
        coordinator.store.state.rating.enrollmentDate = enrollment
        coordinator.store.state.rating.distinctProbableGameDates = [firstDate, secondDate]
        XCTAssertTrue(coordinator.store.save())

        XCTAssertEqual(
            RollCallRatingPolicy.automaticOpportunity(for: coordinator.store.state.rating, now: secondDate),
            1
        )
        let token = coordinator.reserveRatingPresentation(source: .automatic, now: secondDate)
        XCTAssertNotNil(token)
        XCTAssertEqual(coordinator.store.state.rating.automaticAttemptsConsumed, 0)

        coordinator.confirmRatingPresentation(token: token!, now: secondDate)
        XCTAssertEqual(coordinator.store.state.rating.automaticAttemptsConsumed, 1)
        XCTAssertEqual(coordinator.store.state.rating.presentationCooldownAnchor, secondDate)
    }

    func testSecondOpportunityNeedsFiveDatesAndThirtyDaysAfterFirstSheet() {
        let enrollment = Date(timeIntervalSince1970: 2_000_000)
        let firstSheet = enrollment.addingTimeInterval(7 * 86_400)
        let dates = (0..<5).map { firstSheet.addingTimeInterval(TimeInterval($0) * 86_400) }
        let coordinator = coordinator(now: enrollment)
        coordinator.store.state.rating.enrollmentDate = enrollment
        coordinator.store.state.rating.distinctProbableGameDates = dates
        coordinator.store.state.rating.automaticAttemptsConsumed = 1
        coordinator.store.state.rating.presentationCooldownAnchor = firstSheet
        XCTAssertTrue(coordinator.store.save())

        XCTAssertNil(
            RollCallRatingPolicy.automaticOpportunity(
                for: coordinator.store.state.rating,
                now: firstSheet.addingTimeInterval(30 * 86_400 - 1)
            )
        )
        XCTAssertEqual(
            RollCallRatingPolicy.automaticOpportunity(
                for: coordinator.store.state.rating,
                now: firstSheet.addingTimeInterval(30 * 86_400)
            ),
            2
        )
    }

    func testManualSheetCooldownDelaysFirstAutomaticOpportunity() {
        let enrollment = Date(timeIntervalSince1970: 4_000_000)
        let coordinator = coordinator(now: enrollment)
        coordinator.store.state.rating.enrollmentDate = enrollment
        coordinator.store.state.rating.distinctProbableGameDates = [
            enrollment.addingTimeInterval(7 * 86_400),
            enrollment.addingTimeInterval(8 * 86_400)
        ]
        XCTAssertTrue(coordinator.store.save())

        let manualToken = coordinator.reserveRatingPresentation(source: .manual, now: enrollment.addingTimeInterval(8 * 86_400))
        XCTAssertNotNil(manualToken)
        coordinator.confirmRatingPresentation(token: manualToken!, now: enrollment.addingTimeInterval(8 * 86_400))

        XCTAssertNil(
            RollCallRatingPolicy.automaticOpportunity(
                for: coordinator.store.state.rating,
                now: enrollment.addingTimeInterval(8 * 86_400 + 30 * 86_400 - 1)
            )
        )
        XCTAssertEqual(
            RollCallRatingPolicy.automaticOpportunity(
                for: coordinator.store.state.rating,
                now: enrollment.addingTimeInterval(8 * 86_400 + 30 * 86_400)
            ),
            1
        )
    }

    func testAutomaticPresentationIsAppStoreOnlyButManualCooldownAndSuppressionRemain() {
        let now = Date(timeIntervalSince1970: 3_000_000)
        let developer = coordinator(isAppStoreBuild: false, now: now)
        developer.store.state.rating.enrollmentDate = now.addingTimeInterval(-7 * 86_400)
        developer.store.state.rating.distinctProbableGameDates = [now.addingTimeInterval(-2 * 86_400), now.addingTimeInterval(-86_400)]
        XCTAssertTrue(developer.store.save())
        XCTAssertFalse(developer.canPresentAutomaticRatingRequest)
        XCTAssertNil(developer.reserveRatingPresentation(source: .automatic, now: now))

        let manualToken = developer.reserveRatingPresentation(source: .manual, now: now)
        XCTAssertNotNil(manualToken)
        developer.confirmRatingPresentation(token: manualToken!, now: now)
        XCTAssertEqual(developer.store.state.rating.presentationCooldownAnchor, now)

        developer.recordRatingAction(.ratingRateSelected, suppressesAutomatic: true)
        XCTAssertTrue(developer.store.state.rating.permanentlySuppressed)
        XCTAssertNil(RollCallRatingPolicy.automaticOpportunity(for: developer.store.state.rating, now: now.addingTimeInterval(365 * 86_400)))
    }
}
