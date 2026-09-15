import XCTest
@testable import SceneCore

/// V0.7.4 made the tiling rect stable under a roaming Dock by reserving the
/// Dock's thickness on *every* display. The cost is a dead strip along the
/// bottom of whichever display the Dock is not on. `dockReserveAllDisplays`
/// lets a user who would rather have windows flush to the bottom trade that
/// stability away.
final class DockReserveTests: XCTestCase {
    private let frameA = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    private let frameB = CGRect(x: 1000, y: 0, width: 1000, height: 1000)
    private let menuBar: CGFloat = 25
    private let dock: CGFloat = 70

    private func vf(_ frame: CGRect, dockAtBottom: Bool) -> CGRect {
        let bottom = dockAtBottom ? dock : 0
        return CGRect(x: frame.minX, y: frame.minY + bottom,
                      width: frame.width, height: frame.height - menuBar - bottom)
    }

    private func insets(_ frame: CGRect, _ visible: CGRect) -> ScreenInsets {
        ScreenInsets(frame: frame, visibleFrame: visible)
    }

    /// Dock on display A; we are tiling display B.
    private var dockOnA: (own: ScreenInsets, all: [ScreenInsets]) {
        let a = insets(frameA, vf(frameA, dockAtBottom: true))
        let b = insets(frameB, vf(frameB, dockAtBottom: false))
        return (own: b, all: [a, b])
    }

    // MARK: - opted out

    func testDocklessDisplayReachesTheBottomWhenReserveIsOff() {
        let (own, all) = dockOnA
        let rect = TilingFrame.compute(frame: frameB, ownInsets: own, allInsets: all,
                                       reserveDockOnAllDisplays: false)
        XCTAssertEqual(rect.minY, frameB.minY, "windows should sit flush on the bottom edge")
        XCTAssertEqual(rect.height, frameB.height - menuBar)
    }

    func testDisplayHoldingTheDockStillReservesItWhenReserveIsOff() {
        let a = insets(frameA, vf(frameA, dockAtBottom: true))
        let b = insets(frameB, vf(frameB, dockAtBottom: false))
        let rect = TilingFrame.compute(frame: frameA, ownInsets: a, allInsets: [a, b],
                                       reserveDockOnAllDisplays: false)
        XCTAssertEqual(rect.minY, frameA.minY + dock, "the Dock's own display must not tile under it")
    }

    // MARK: - opted in (the V0.7.4 default)

    func testDocklessDisplayKeepsTheReserveWhenReserveIsOn() {
        let (own, all) = dockOnA
        let rect = TilingFrame.compute(frame: frameB, ownInsets: own, allInsets: all,
                                       reserveDockOnAllDisplays: true)
        XCTAssertEqual(rect.minY, frameB.minY + dock)
    }

    /// The flag must not change the default behaviour callers already rely on.
    func testReserveDefaultsToOn() {
        let (own, all) = dockOnA
        XCTAssertEqual(
            TilingFrame.compute(frame: frameB, ownInsets: own, allInsets: all),
            TilingFrame.compute(frame: frameB, ownInsets: own, allInsets: all,
                                reserveDockOnAllDisplays: true)
        )
    }

    // MARK: - single display

    /// On one display the unified maximum is that screen's own inset, so the
    /// flag is a no-op. A single-display user can never be affected either way.
    func testSingleDisplayIsIdenticalWithAndWithoutReserve() {
        let a = insets(frameA, vf(frameA, dockAtBottom: true))
        XCTAssertEqual(
            TilingFrame.compute(frame: frameA, ownInsets: a, allInsets: [a],
                                reserveDockOnAllDisplays: true),
            TilingFrame.compute(frame: frameA, ownInsets: a, allInsets: [a],
                                reserveDockOnAllDisplays: false)
        )
    }
}

/// Persistence for the Dock-reserve escape hatch.
final class DockReserveSettingsTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-dock-reserve-tests-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    func testDefaultsToReservingOnAllDisplays() throws {
        XCTAssertTrue(try SettingsStore(fileURL: fileURL).dockReserveAllDisplays)
    }

    func testSetterPersistsAcrossReload() throws {
        let store = try SettingsStore(fileURL: fileURL)
        try store.setDockReserveAllDisplays(false)
        XCTAssertFalse(store.dockReserveAllDisplays)
        XCTAssertFalse(try SettingsStore(fileURL: fileURL).dockReserveAllDisplays)
    }

    func testSetterNotifiesObservers() throws {
        let store = try SettingsStore(fileURL: fileURL)
        var fired = 0
        let token = store.onChange { fired += 1 }
        try store.setDockReserveAllDisplays(false)
        XCTAssertEqual(fired, 1)
        token.cancel()
    }

    /// Someone upgrading from V0.7.5 must keep the stable-tiling behaviour they
    /// already have; the escape hatch is opt-in, never opt-out.
    func testV3FileMigratesWithReserveStillOn() throws {
        let v3 = """
        {"version":3,
         "animation":{"enabled":true,"durationMs":250,"easing":"easeOut"},
         "dragSwap":{"enabled":true,"distanceThresholdPt":30},
         "diagnosticsEnabled":true}
        """
        try Data(v3.utf8).write(to: fileURL)
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertTrue(store.dockReserveAllDisplays)
        // and the migration must have rewritten the file at the new version
        let probe = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as! [String: Any]
        XCTAssertEqual(probe["version"] as? Int, SettingsStore.currentVersion)
    }

    func testMigratedV3FileKeepsItsOtherSettings() throws {
        let v3 = """
        {"version":3,
         "animation":{"enabled":false,"durationMs":400,"easing":"spring"},
         "dragSwap":{"enabled":false,"distanceThresholdPt":45},
         "diagnosticsEnabled":false}
        """
        try Data(v3.utf8).write(to: fileURL)
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.animation, AnimationConfig(enabled: false, durationMs: 400, easing: .spring))
        XCTAssertEqual(store.dragSwap, DragSwapConfig(enabled: false, distanceThresholdPt: 45))
        XCTAssertFalse(store.diagnosticsEnabled)
    }
}
