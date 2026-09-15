import XCTest
@testable import SceneCore

final class StarPromptStateTests: XCTestCase {

    // MARK: - gating

    func testFreshStateDoesNotPrompt() {
        XCTAssertFalse(StarPromptState().shouldPrompt)
    }

    func testDoesNotPromptOneApplyBelowThreshold() {
        var s = StarPromptState()
        for _ in 0..<(StarPromptState.promptThreshold - 1) { s.recordSuccessfulApply() }
        XCTAssertFalse(s.shouldPrompt)
    }

    func testPromptsExactlyAtThreshold() {
        var s = StarPromptState()
        for _ in 0..<StarPromptState.promptThreshold { s.recordSuccessfulApply() }
        XCTAssertTrue(s.shouldPrompt)
    }

    func testKeepsPromptingAboveThresholdUntilResolved() {
        var s = StarPromptState()
        for _ in 0..<(StarPromptState.promptThreshold + 25) { s.recordSuccessfulApply() }
        XCTAssertTrue(s.shouldPrompt)
    }

    // MARK: - resolution is permanent

    func testNeverPromptsAgainOnceStarred() {
        var s = StarPromptState()
        for _ in 0..<StarPromptState.promptThreshold { s.recordSuccessfulApply() }
        s.resolve(.starred)
        XCTAssertFalse(s.shouldPrompt)
    }

    func testNeverPromptsAgainOnceDismissed() {
        var s = StarPromptState()
        for _ in 0..<StarPromptState.promptThreshold { s.recordSuccessfulApply() }
        s.resolve(.dismissed)
        XCTAssertFalse(s.shouldPrompt)
    }

    func testFurtherAppliesDoNotReArmAResolvedPrompt() {
        var s = StarPromptState()
        for _ in 0..<StarPromptState.promptThreshold { s.recordSuccessfulApply() }
        s.resolve(.dismissed)
        for _ in 0..<100 { s.recordSuccessfulApply() }
        XCTAssertFalse(s.shouldPrompt)
    }

    // MARK: - counting

    func testRecordingIncrementsCount() {
        var s = StarPromptState()
        s.recordSuccessfulApply()
        s.recordSuccessfulApply()
        XCTAssertEqual(s.successfulApplyCount, 2)
    }

    /// Once resolved the count is dead weight — it must stop growing so a
    /// long-lived install cannot overflow it.
    func testCountStopsGrowingAfterResolution() {
        var s = StarPromptState()
        s.resolve(.dismissed)
        s.recordSuccessfulApply()
        XCTAssertEqual(s.successfulApplyCount, 0)
    }

    func testCountSaturatesAtThresholdWhilePending() {
        var s = StarPromptState()
        for _ in 0..<10_000 { s.recordSuccessfulApply() }
        XCTAssertEqual(s.successfulApplyCount, StarPromptState.promptThreshold)
    }

    // MARK: - persistence

    func testCodableRoundTrip() throws {
        var s = StarPromptState()
        s.recordSuccessfulApply()
        s.recordSuccessfulApply()
        s.resolve(.starred)
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(StarPromptState.self, from: data), s)
    }

    /// A state written by a future build with a resolution this build does not
    /// know must not crash decoding, and must not spuriously prompt.
    func testDecodingUnknownResolutionIsTreatedAsResolved() throws {
        let json = #"{"successfulApplyCount":99,"resolution":"snoozed_until_next_year"}"#
        let s = try JSONDecoder().decode(StarPromptState.self, from: Data(json.utf8))
        XCTAssertFalse(s.shouldPrompt)
    }

    func testNegativeCountOnDiskIsClampedToZero() throws {
        let json = #"{"successfulApplyCount":-5,"resolution":"pending"}"#
        let s = try JSONDecoder().decode(StarPromptState.self, from: Data(json.utf8))
        XCTAssertEqual(s.successfulApplyCount, 0)
        XCTAssertFalse(s.shouldPrompt)
    }
}
