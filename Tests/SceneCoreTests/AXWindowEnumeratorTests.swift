import CoreGraphics
import XCTest
@testable import SceneCore

final class AXWindowEnumeratorTests: XCTestCase {
    func testSameFrameWindowsUseDistinctAXCandidates() {
        let sharedFrame = CGRect(x: 0, y: 31, width: 853, height: 1_049)
        let frames = [sharedFrame, sharedFrame]

        let first = AXWindowEnumerator.firstUnclaimedCandidateIndex(
            candidateFrames: frames,
            matching: sharedFrame,
            claimedIndexes: []
        )
        let second = AXWindowEnumerator.firstUnclaimedCandidateIndex(
            candidateFrames: frames,
            matching: sharedFrame,
            claimedIndexes: [first!]
        )

        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 1)
    }

    func testCandidateMatchingStillUsesFrameTolerance() {
        let target = CGRect(x: 10, y: 20, width: 300, height: 200)
        let frames = [
            CGRect(x: 13, y: 20, width: 300, height: 200),
            CGRect(x: 11, y: 19, width: 299, height: 201)
        ]

        let match = AXWindowEnumerator.firstUnclaimedCandidateIndex(
            candidateFrames: frames,
            matching: target,
            claimedIndexes: [0]
        )

        XCTAssertEqual(match, 1)
    }
}
