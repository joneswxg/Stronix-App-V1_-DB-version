import XCTest
@testable import Stronix

@MainActor
final class StartupGatePresentationTests: XCTestCase {
    func testPreparingDatabasePresentsVisibleLoadingStatus() {
        let presentation = StartupGatePresentation(state: .preparingDatabase)

        XCTAssertTrue(presentation.isLoading)
        XCTAssertNil(presentation.blockReason)
    }

    func testRestoringSessionPresentsVisibleLoadingStatus() {
        let presentation = StartupGatePresentation(state: .restoringSession)

        XCTAssertTrue(presentation.isLoading)
        XCTAssertNil(presentation.blockReason)
    }

    func testBlockedStartupRetainsItsRetryPolicy() {
        let recoverable = StartupGatePresentation(
            state: .blocked(.recoverablePreparationFailure)
        )
        let terminal = StartupGatePresentation(
            state: .blocked(.incompatibleSchema)
        )

        XCTAssertEqual(recoverable.blockReason, .recoverablePreparationFailure)
        XCTAssertTrue(recoverable.blockReason?.permitsRetry == true)
        XCTAssertEqual(terminal.blockReason, .incompatibleSchema)
        XCTAssertFalse(terminal.blockReason?.permitsRetry == true)
    }

    func testReadyDoesNotPresentStartupContent() {
        let presentation = StartupGatePresentation(state: .ready)

        XCTAssertFalse(presentation.isLoading)
        XCTAssertNil(presentation.blockReason)
    }
}
