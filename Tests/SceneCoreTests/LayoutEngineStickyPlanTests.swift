import XCTest
@testable import SceneCore

final class LayoutEngineStickyPlanTests: XCTestCase {
    let vf = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    // Quads slot rects materialized in vf (absoluteRect flips y):
    // slot 0 = top-left, slot 1 = top-right, slot 2 = bottom-left, slot 3 = bottom-right.
    private var q0: CGRect { CGRect(x: 0,   y: 500, width: 500, height: 500) }
    private var q1: CGRect { CGRect(x: 500, y: 500, width: 500, height: 500) }
    private var q2: CGRect { CGRect(x: 0,   y: 0,   width: 500, height: 500) }
    private var q3: CGRect { CGRect(x: 500, y: 0,   width: 500, height: 500) }

    func testFullReapplyIsVisuallyStationary() {
        // 4 windows already exactly on the quad rects, in scrambled z-order.
        let ws = [
            MockWindow(id: 3, frame: q2),
            MockWindow(id: 1, frame: q0),
            MockWindow(id: 4, frame: q3),
            MockWindow(id: 2, frame: q1),
        ]
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .quads)
        XCTAssertEqual(plan.placements, [
            Placement(windowID: 1, targetFrame: q0, slotIndex: 0),
            Placement(windowID: 2, targetFrame: q1, slotIndex: 1),
            Placement(windowID: 3, targetFrame: q2, slotIndex: 2),
            Placement(windowID: 4, targetFrame: q3, slotIndex: 3),
        ])
        XCTAssertTrue(plan.toMinimize.isEmpty)
        XCTAssertEqual(plan.leftEmptySlotCount, 0)
    }

    func testCloseOneAddOneOnlyMovesTheNewWindow() {
        // Slots 0, 1, 3 occupied; slot 2's window was closed and a new
        // frontmost window (id 9, arbitrary frame) was opened.
        let ws = [
            MockWindow(id: 9, frame: CGRect(x: 120, y: 340, width: 600, height: 400)),
            MockWindow(id: 1, frame: q0),
            MockWindow(id: 2, frame: q1),
            MockWindow(id: 4, frame: q3),
        ]
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .quads)
        XCTAssertEqual(plan.placements, [
            Placement(windowID: 1, targetFrame: q0, slotIndex: 0),
            Placement(windowID: 2, targetFrame: q1, slotIndex: 1),
            Placement(windowID: 9, targetFrame: q2, slotIndex: 2),
            Placement(windowID: 4, targetFrame: q3, slotIndex: 3),
        ])
        XCTAssertTrue(plan.toMinimize.isEmpty)
        XCTAssertEqual(plan.leftEmptySlotCount, 0)
    }

    func testSwappedWindowsKeepSwappedSlots() {
        // User drag-swapped windows 1 and 2: 1 sits on slot 1's rect, 2 on slot 0's.
        let ws = [
            MockWindow(id: 1, frame: q1),
            MockWindow(id: 2, frame: q0),
            MockWindow(id: 3, frame: q2),
            MockWindow(id: 4, frame: q3),
        ]
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .quads)
        XCTAssertEqual(plan.placements.first { $0.windowID == 1 }?.slotIndex, 1)
        XCTAssertEqual(plan.placements.first { $0.windowID == 2 }?.slotIndex, 0)
    }

    func testOverflowMinimizesLeftoverNotSticky() {
        // All 4 slots sticky plus a new 5th window: the newcomer minimizes,
        // the 4 placed windows are untouched.
        let ws = [
            MockWindow(id: 9, frame: CGRect(x: 100, y: 100, width: 300, height: 300)),
            MockWindow(id: 1, frame: q0),
            MockWindow(id: 2, frame: q1),
            MockWindow(id: 3, frame: q2),
            MockWindow(id: 4, frame: q3),
        ]
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .quads)
        XCTAssertEqual(plan.toMinimize, [9])
        XCTAssertEqual(Set(plan.placements.map(\.windowID)), [1, 2, 3, 4])
    }

    func testDifferentLayoutRemapsByZOrder() {
        // Windows sit on quad rects; thirds shares no rect with quads, so the
        // sticky pass matches nothing and fill is pure z-order like today.
        let ws = [
            MockWindow(id: 1, frame: q0),
            MockWindow(id: 2, frame: q1),
            MockWindow(id: 3, frame: q2),
        ]
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .thirds)
        XCTAssertEqual(plan.placements.map(\.windowID), [1, 2, 3])
        XCTAssertEqual(plan.placements.map(\.slotIndex), [0, 1, 2])
    }

    func testToleranceEdges() {
        // 8pt off is sticky (default tolerance 10) and self-heals to the
        // exact rect; 12pt off is not sticky and falls to the fill pass.
        let near = MockWindow(id: 1, frame: q0.offsetBy(dx: 8, dy: 0))
        let far  = MockWindow(id: 2, frame: q1.offsetBy(dx: 12, dy: 0))
        let plan = LayoutEngine.plan(windows: [far, near], visibleFrame: vf, layout: .quads)
        XCTAssertEqual(plan.placements.first { $0.windowID == 1 }?.slotIndex, 0)
        XCTAssertEqual(plan.placements.first { $0.windowID == 1 }?.targetFrame, q0)
        // far is frontmost non-sticky; first free slot in index order is 1.
        XCTAssertEqual(plan.placements.first { $0.windowID == 2 }?.slotIndex, 1)
    }

    func testStackedWindowsFirstInZOrderClaims() {
        // Two windows on the same slot rect: the frontmost claims it, the
        // other falls through to the fill pass and gets the next free slot.
        let ws = [
            MockWindow(id: 1, frame: q0),
            MockWindow(id: 2, frame: q0),
        ]
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .quads)
        XCTAssertEqual(plan.placements.first { $0.windowID == 1 }?.slotIndex, 0)
        XCTAssertEqual(plan.placements.first { $0.windowID == 2 }?.slotIndex, 1)
    }

    func testUnderflowGapReportsEmptySlots() {
        // Slots 0, 2, 3 sticky; slot 1's window was closed; nothing new opened.
        let ws = [
            MockWindow(id: 1, frame: q0),
            MockWindow(id: 3, frame: q2),
            MockWindow(id: 4, frame: q3),
        ]
        let plan = LayoutEngine.plan(windows: ws, visibleFrame: vf, layout: .quads)
        XCTAssertEqual(plan.placements.map(\.slotIndex), [0, 2, 3])
        XCTAssertEqual(plan.leftEmptySlotCount, 1)
        XCTAssertTrue(plan.toMinimize.isEmpty)
    }

    // MARK: - Dock hops between displays

    /// Halves tiled while the Dock sat on this display (bottom 70pt reserved),
    /// then the Dock hopped to the other display. Re-applying against the now
    /// taller frame must keep each window in its slot and only stretch it —
    /// not reshuffle by z-order because no window matches the new rects.
    func testReapplyAfterTheDockLeavesKeepsEveryWindowInItsSlot() {
        let withDock = CGRect(x: 0, y: 70, width: 1000, height: 930)
        let withoutDock = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let left = CGRect(x: 0, y: 70, width: 500, height: 930)
        let right = CGRect(x: 500, y: 70, width: 500, height: 930)
        // Right-hand window is frontmost, so a z-order fill would put it left.
        let ws = [MockWindow(id: 2, frame: right), MockWindow(id: 1, frame: left)]

        let plan = LayoutEngine.plan(
            windows: ws, visibleFrame: withoutDock, layout: .halves,
            alternateFrames: [withDock]
        )

        XCTAssertEqual(plan.placements, [
            Placement(windowID: 1, targetFrame: CGRect(x: 0, y: 0, width: 500, height: 1000), slotIndex: 0),
            Placement(windowID: 2, targetFrame: CGRect(x: 500, y: 0, width: 500, height: 1000), slotIndex: 1),
        ])
    }

    /// Without the alternate frame the same re-apply reshuffles — the bug the
    /// unified Dock reserve used to paper over.
    func testReapplyAfterTheDockLeavesReshufflesWithoutAlternates() {
        let withoutDock = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let left = CGRect(x: 0, y: 70, width: 500, height: 930)
        let right = CGRect(x: 500, y: 70, width: 500, height: 930)
        let ws = [MockWindow(id: 2, frame: right), MockWindow(id: 1, frame: left)]

        let plan = LayoutEngine.plan(windows: ws, visibleFrame: withoutDock, layout: .halves)

        XCTAssertEqual(plan.placements.first { $0.slotIndex == 0 }?.windowID, 2)
    }

    /// The primary frame wins when a window matches both it and an alternate.
    func testPrimaryFrameMatchTakesPriorityOverAlternate() {
        let withDock = CGRect(x: 0, y: 70, width: 1000, height: 930)
        let withoutDock = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let ws = [
            MockWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 500, height: 1000)),
            MockWindow(id: 2, frame: CGRect(x: 0, y: 70, width: 500, height: 930)),
        ]
        let plan = LayoutEngine.plan(
            windows: ws, visibleFrame: withoutDock, layout: .halves,
            alternateFrames: [withDock]
        )
        XCTAssertEqual(plan.placements.first { $0.slotIndex == 0 }?.windowID, 1)
        XCTAssertEqual(plan.placements.first { $0.slotIndex == 1 }?.windowID, 2)
    }
}
