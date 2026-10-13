import XCTest
import CoreGraphics
@testable import SceneCore

/// Every display keeps its own record of what its last layout fire placed.
/// Before this, one global snapshot meant applying a layout on display B
/// switched drag-swap off on display A, and a window moved to another display
/// stayed recorded in its old slot until something pulled it back.
final class PlacementRegistryTests: XCTestCase {
    private let displayA: CGDirectDisplayID = 1
    private let displayB: CGDirectDisplayID = 2
    private let frameA = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let frameB = CGRect(x: -1000, y: 0, width: 1000, height: 800)

    private func snapshot(_ ids: [CGWindowID], frame: CGRect) -> PlacementSnapshot {
        let layout = CustomLayout(
            id: UUID(), name: "Halves", template: .twoCol, slotProportions: [0.5],
            hotkey: nil, isPresetSeed: false, isModified: false
        )
        return PlacementSnapshot(
            layout: layout.toLayout(),
            customLayout: layout,
            windows: ids.map { MockWindow(id: $0) },
            windowToSlotIdx: Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) }),
            tilingFrame: frame,
            screenFrame: frame
        )
    }

    func testRecordingOneDisplayKeepsTheOther() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1, 2], frame: frameA), on: displayA, liveDisplays: [displayA, displayB])
        registry.record(snapshot([3, 4], frame: frameB), on: displayB, liveDisplays: [displayA, displayB])

        XCTAssertEqual(registry.snapshot(holding: 1)?.displayID, displayA)
        XCTAssertEqual(registry.snapshot(holding: 4)?.displayID, displayB)
        XCTAssertEqual(registry.observedWindowIDs, [1, 2, 3, 4])
    }

    func testReapplyingADisplayReplacesOnlyThatDisplay() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1, 2], frame: frameA), on: displayA, liveDisplays: [displayA, displayB])
        registry.record(snapshot([3, 4], frame: frameB), on: displayB, liveDisplays: [displayA, displayB])
        registry.record(snapshot([5], frame: frameB), on: displayB, liveDisplays: [displayA, displayB])

        XCTAssertNil(registry.snapshot(holding: 3))
        XCTAssertEqual(registry.observedWindowIDs, [1, 2, 5])
    }

    /// A window lives in one layout at a time: tiling it on B takes it out of
    /// A's record, so a swap on A cannot pull it back.
    func testWindowTiledOnAnotherDisplayLeavesItsOldRecord() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1, 2], frame: frameA), on: displayA, liveDisplays: [displayA, displayB])
        registry.record(snapshot([2, 3], frame: frameB), on: displayB, liveDisplays: [displayA, displayB])

        XCTAssertEqual(registry.snapshot(holding: 2)?.displayID, displayB)
        XCTAssertEqual(registry.snapshots[displayA]?.windowToSlotIdx, [1: 0])
        XCTAssertEqual(registry.snapshots[displayA]?.windows.map(\.id), [1])
    }

    func testForgetDropsWindowsAndEmptyRecords() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1, 2], frame: frameA), on: displayA, liveDisplays: [displayA, displayB])
        registry.record(snapshot([3], frame: frameB), on: displayB, liveDisplays: [displayA, displayB])

        registry.forget([2, 3])

        XCTAssertEqual(registry.snapshots[displayA]?.windowToSlotIdx, [1: 0])
        XCTAssertNil(registry.snapshots[displayB], "a display with nothing left tiled has no record")
        XCTAssertEqual(registry.observedWindowIDs, [1])
    }

    func testSlotUpdatesGoToTheOwningDisplay() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1, 2], frame: frameA), on: displayA, liveDisplays: [displayA, displayB])
        registry.record(snapshot([3, 4], frame: frameB), on: displayB, liveDisplays: [displayA, displayB])

        registry.applySlotUpdates([3: 1, 4: 0])

        XCTAssertEqual(registry.snapshots[displayB]?.windowToSlotIdx, [3: 1, 4: 0])
        XCTAssertEqual(registry.snapshots[displayA]?.windowToSlotIdx, [1: 0, 2: 1])
    }

    /// An update for a window no display holds is ignored rather than
    /// inventing a record for it.
    func testSlotUpdateForUnknownWindowIsIgnored() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1], frame: frameA), on: displayA, liveDisplays: [displayA])
        registry.applySlotUpdates([99: 0])
        XCTAssertEqual(registry.observedWindowIDs, [1])
    }

    func testRecordingDropsDisplaysThatWereUnplugged() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1], frame: frameA), on: displayA, liveDisplays: [displayA, displayB])
        registry.record(snapshot([3], frame: frameB), on: displayB, liveDisplays: [displayB])

        XCTAssertNil(registry.snapshots[displayA])
        XCTAssertEqual(registry.observedWindowIDs, [3])
    }

    func testRecordingNothingClearsTheDisplay() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1], frame: frameA), on: displayA, liveDisplays: [displayA])
        registry.record(snapshot([], frame: frameA), on: displayA, liveDisplays: [displayA])
        XCTAssertNil(registry.snapshots[displayA])
    }

    func testRemoveAllForgetsEveryDisplay() {
        let registry = PlacementRegistry()
        registry.record(snapshot([1], frame: frameA), on: displayA, liveDisplays: [displayA, displayB])
        registry.record(snapshot([3], frame: frameB), on: displayB, liveDisplays: [displayA, displayB])
        registry.removeAll()
        XCTAssertTrue(registry.observedWindowIDs.isEmpty)
    }
}
