import XCTest
@testable import RollCall

final class CustomAnnouncerRecorderTests: XCTestCase {
    func testCancellationClaimsActiveRecordingAndAllowsNextSession() {
        let state = CustomAnnouncerStopState()
        let firstSession = UUID()
        let secondSession = UUID()
        let firstURL = URL(fileURLWithPath: "/tmp/roll-call-first.caf")
        let secondURL = URL(fileURLWithPath: "/tmp/roll-call-second.caf")
        let firstRecorder = NSObject()
        let secondRecorder = NSObject()

        XCTAssertTrue(state.beginRecording(
            sessionID: firstSession,
            url: firstURL,
            recorder: firstRecorder,
            onBegin: {}
        ))
        let cancellation = state.cancel(onClaim: {})

        XCTAssertEqual(cancellation.url, firstURL)
        XCTAssertNil(cancellation.continuation)
        XCTAssertFalse(state.cancel(onClaim: {}).claimed)
        XCTAssertTrue(state.beginRecording(
            sessionID: secondSession,
            url: secondURL,
            recorder: secondRecorder,
            onBegin: {}
        ))
    }

    func testCallbackWinsAndLateCancellationCannotClaimCompletedSession() async {
        let state = CustomAnnouncerStopState()
        let sessionID = UUID()
        let destinationURL = URL(fileURLWithPath: "/tmp/roll-call-callback.caf")
        let recorder = NSObject()
        XCTAssertTrue(state.beginRecording(
            sessionID: sessionID,
            url: destinationURL,
            recorder: recorder,
            onBegin: {}
        ))

        let result = await stopResult(
            state: state,
            sessionID: sessionID,
            recorder: recorder,
            destinationURL: destinationURL,
            cancellationWins: false
        )

        guard case .success(let returnedURL) = result else {
            return XCTFail("Expected the recorder callback to complete the stop")
        }
        XCTAssertEqual(returnedURL, destinationURL)
        XCTAssertFalse(state.cancel(onClaim: {}).claimed)
        XCTAssertNil(state.takePendingStop(
            sessionID: sessionID,
            recorder: recorder,
            onComplete: {}
        ).0)
    }

    func testCancellationWinsAndLateCallbackCannotResumeTwice() async {
        let state = CustomAnnouncerStopState()
        let sessionID = UUID()
        let destinationURL = URL(fileURLWithPath: "/tmp/roll-call-cancel.caf")
        let recorder = NSObject()
        XCTAssertTrue(state.beginRecording(
            sessionID: sessionID,
            url: destinationURL,
            recorder: recorder,
            onBegin: {}
        ))

        let result = await stopResult(
            state: state,
            sessionID: sessionID,
            recorder: recorder,
            destinationURL: destinationURL,
            cancellationWins: true
        )

        guard case .failure(let error) = result else {
            return XCTFail("Expected cancellation to finish the pending stop")
        }
        guard let appError = error as? AppError, case .recordingCancelled = appError else {
            return XCTFail("Expected the cancellation error, got \(error)")
        }
        XCTAssertFalse(state.cancel(onClaim: {}).claimed)
        XCTAssertNil(state.takePendingStop(
            sessionID: sessionID,
            recorder: recorder,
            onComplete: {}
        ).0)
    }

    func testStaleCallbackCannotClaimSubsequentRecording() {
        let state = CustomAnnouncerStopState()
        let oldSessionID = UUID()
        let newSessionID = UUID()
        let oldURL = URL(fileURLWithPath: "/tmp/roll-call-old.caf")
        let newURL = URL(fileURLWithPath: "/tmp/roll-call-new.caf")
        let oldRecorder = NSObject()
        let newRecorder = NSObject()

        XCTAssertTrue(state.beginRecording(
            sessionID: oldSessionID,
            url: oldURL,
            recorder: oldRecorder,
            onBegin: {}
        ))
        let oldCancellation = state.cancel(onClaim: {})
        XCTAssertEqual(oldCancellation.url, oldURL)
        XCTAssertTrue(state.beginRecording(
            sessionID: newSessionID,
            url: newURL,
            recorder: newRecorder,
            onBegin: {}
        ))

        XCTAssertNil(state.takePendingStop(
            sessionID: oldSessionID,
            recorder: oldRecorder,
            onComplete: {}
        ).0)
        let newCancellation = state.cancel(onClaim: {})
        XCTAssertEqual(newCancellation.url, newURL)
    }

    private func stopResult(
        state: CustomAnnouncerStopState,
        sessionID: UUID,
        recorder: AnyObject,
        destinationURL: URL,
        cancellationWins: Bool
    ) async -> Result<URL, Error> {
        do {
            let returnedURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                XCTAssertTrue(state.beginStop(
                    sessionID: sessionID,
                    recorder: recorder,
                    continuation: continuation
                ))
                if cancellationWins {
                    state.cancel(onClaim: {}).continuation?.resume(throwing: AppError.recordingCancelled)
                } else {
                    state.takePendingStop(
                        sessionID: sessionID,
                        recorder: recorder,
                        onComplete: {}
                    ).1?.resume(returning: destinationURL)
                }
            }
            return .success(returnedURL)
        } catch {
            return .failure(error)
        }
    }
}
