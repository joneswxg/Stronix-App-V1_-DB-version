import XCTest
@testable import Stronix

final class PlanCardPresentationTests: XCTestCase {
    func testEmptyActionsShowEmptyState() {
        let nilPresentation = PlanCardPresentation(actions: nil)
        let emptyPresentation = PlanCardPresentation(actions: [])

        XCTAssertTrue(nilPresentation.showsEmptyState)
        XCTAssertTrue(emptyPresentation.showsEmptyState)
        XCTAssertTrue(nilPresentation.visibleActions().isEmpty)
        XCTAssertTrue(emptyPresentation.visibleActions().isEmpty)
        XCTAssertEqual(nilPresentation.remainingActionCount(), 0)
        XCTAssertEqual(emptyPresentation.remainingActionCount(), 0)
    }

    func testUpToThreeActionsAreVisibleInOrder() {
        let actions = [
            makeAction(id: 1, name: "动作一"),
            makeAction(id: 2, name: "动作二"),
            makeAction(id: 3, name: "动作三")
        ]
        let presentation = PlanCardPresentation(actions: actions)

        XCTAssertFalse(presentation.showsEmptyState)
        XCTAssertEqual(presentation.visibleActions().map(\.id), [1, 2, 3])
        XCTAssertEqual(presentation.remainingActionCount(), 0)
    }

    func testFourActionsShowThreeAndOneRemaining() {
        let presentation = PlanCardPresentation(actions: (1...4).map { makeAction(id: $0, name: "动作\($0)") })

        XCTAssertEqual(presentation.visibleActions().map(\.id), [1, 2, 3])
        XCTAssertEqual(presentation.remainingActionCount(), 1)
    }

    func testMoreThanFourActionsShowThreeAndExactRemainder() {
        let presentation = PlanCardPresentation(actions: (1...7).map { makeAction(id: $0, name: "动作\($0)") })

        XCTAssertEqual(presentation.visibleActions().map(\.id), [1, 2, 3])
        XCTAssertEqual(presentation.remainingActionCount(), 4)
    }

    func testAccessibilityPresentationShowsOneActionAndCountsTheRemainder() {
        let presentation = PlanCardPresentation(actions: (1...4).map { makeAction(id: $0, name: "动作\($0)") })

        XCTAssertEqual(presentation.visibleActions(maximum: 1).map(\.id), [1])
        XCTAssertEqual(presentation.remainingActionCount(afterShowing: 1), 3)
    }

    func testCardPresentationConstantsMatchCompactCardRequirements() {
        XCTAssertEqual(PlanCardPresentation.height, 144)
        XCTAssertEqual(PlanCardPresentation.maximumVisibleActionSummaries, 3)
    }

    private func makeAction(id: Int, name: String) -> TrainingAction {
        TrainingAction(id: id, name: name, totalSets: 3, restTime: 60)
    }
}
