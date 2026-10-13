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

    // MARK: - re-apply candidates

    /// Every frame a display could have been tiled into as the Dock roams:
    /// with the Dock's strip reserved and without it. The Dockless display B
    /// is currently flush, but a layout applied while the Dock sat on it is
    /// 70pt shorter at the bottom.
    func testStickyCandidatesCoverTheDisplayWithAndWithoutTheDock() {
        let (own, all) = dockOnA
        let candidates = TilingFrame.stickyCandidates(frame: frameB, ownInsets: own, allInsets: all)
        XCTAssertEqual(Set(candidates.map(\.minY)), [frameB.minY, frameB.minY + dock])
        XCTAssertEqual(candidates.count, 2, "identical rects are listed once")
    }

    /// Same from the side holding the Dock: its frame once the Dock leaves.
    func testStickyCandidatesForTheDocksOwnDisplayIncludeTheDocklessFrame() {
        let a = insets(frameA, vf(frameA, dockAtBottom: true))
        let b = insets(frameB, vf(frameB, dockAtBottom: false))
        let candidates = TilingFrame.stickyCandidates(frame: frameA, ownInsets: a, allInsets: [a, b])
        XCTAssertEqual(Set(candidates.map(\.minY)), [frameA.minY, frameA.minY + dock])
        XCTAssertTrue(candidates.allSatisfy { $0.maxY == frameA.maxY - menuBar },
                      "the menu bar is never part of any candidate")
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

    /// V0.8.2: a fresh install reserves the Dock only on the display it is
    /// actually on, so a Dockless display uses its full height.
    func testDefaultsToReservingOnlyWhereTheDockIs() throws {
        XCTAssertFalse(try SettingsStore(fileURL: fileURL).dockReserveAllDisplays)
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

    /// V0.8.2 moves every upgrader to the new behaviour. Re-apply no longer
    /// depends on the unified reserve to stay put (`LayoutEngine` matches
    /// windows against the Dock-reserved frame too), so the dead strip it
    /// cost on Dockless displays bought nothing.
    func testV4FileMigratesToReservingOnlyWhereTheDockIs() throws {
        let v4 = """
        {"version":4,
         "animation":{"enabled":true,"durationMs":250,"easing":"easeOut"},
         "dragSwap":{"enabled":true,"distanceThresholdPt":30},
         "diagnosticsEnabled":true,
         "dockReserveAllDisplays":true}
        """
        try Data(v4.utf8).write(to: fileURL)
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertFalse(store.dockReserveAllDisplays)
        let probe = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as! [String: Any]
        XCTAssertEqual(probe["version"] as? Int, SettingsStore.currentVersion)
        XCTAssertEqual(probe["dockReserveAllDisplays"] as? Bool, false)
    }

    /// Once on v5, turning the reserve back on is the user's own choice and
    /// must survive a relaunch.
    func testV5FileKeepsAnExplicitReserveChoice() throws {
        let v5 = """
        {"version":5,
         "animation":{"enabled":true,"durationMs":250,"easing":"easeOut"},
         "dragSwap":{"enabled":true,"distanceThresholdPt":30},
         "diagnosticsEnabled":true,
         "dockReserveAllDisplays":true}
        """
        try Data(v5.utf8).write(to: fileURL)
        XCTAssertTrue(try SettingsStore(fileURL: fileURL).dockReserveAllDisplays)
    }

    func testV3FileMigratesToReservingOnlyWhereTheDockIs() throws {
        let v3 = """
        {"version":3,
         "animation":{"enabled":true,"durationMs":250,"easing":"easeOut"},
         "dragSwap":{"enabled":true,"distanceThresholdPt":30},
         "diagnosticsEnabled":true}
        """
        try Data(v3.utf8).write(to: fileURL)
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertFalse(store.dockReserveAllDisplays)
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

/// A settings file written by a *newer* Scene must not brick an older one.
/// `AppDelegate.init` turns any store-init throw into `fatalError`, so an
/// unrecognized schema version was a crash-on-launch for anyone who ran a
/// newer build and then went back — which bumping the schema to v4 made a
/// live possibility rather than a theoretical one.
final class SettingsForwardCompatibilityTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene-forward-compat-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func writeFutureFile() throws {
        let future = """
        {"version":99,
         "animation":{"enabled":false,"durationMs":400,"easing":"spring"},
         "dragSwap":{"enabled":false,"distanceThresholdPt":45},
         "diagnosticsEnabled":false,
         "dockReserveAllDisplays":false,
         "somethingThisBuildHasNeverHeardOf":{"nested":[1,2,3]}}
        """
        try Data(future.utf8).write(to: fileURL)
    }

    func testAFileFromTheFutureLoadsInsteadOfThrowing() throws {
        try writeFutureFile()
        XCTAssertNoThrow(try SettingsStore(fileURL: fileURL))
    }

    func testAFileFromTheFutureKeepsTheSettingsThisBuildUnderstands() throws {
        try writeFutureFile()
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.animation, AnimationConfig(enabled: false, durationMs: 400, easing: .spring))
        XCTAssertEqual(store.dragSwap, DragSwapConfig(enabled: false, distanceThresholdPt: 45))
        XCTAssertFalse(store.diagnosticsEnabled)
        XCTAssertFalse(store.dockReserveAllDisplays)
    }

    /// Reading must not downgrade the file — the user may go straight back to
    /// the newer build, and whatever it stored has to survive the round trip.
    func testAFileFromTheFutureIsNotRewrittenOnLoad() throws {
        try writeFutureFile()
        _ = try SettingsStore(fileURL: fileURL)
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as! [String: Any]
        XCTAssertEqual(raw["version"] as? Int, 99, "load must leave a newer file alone")
        XCTAssertNotNil(raw["somethingThisBuildHasNeverHeardOf"])
    }

    /// A future file missing a field this build needs falls back to the
    /// default rather than refusing to load.
    func testAFileFromTheFutureMissingAKnownFieldUsesDefaults() throws {
        let sparse = """
        {"version":99,"animation":{"enabled":true,"durationMs":250,"easing":"easeOut"}}
        """
        try Data(sparse.utf8).write(to: fileURL)
        let store = try SettingsStore(fileURL: fileURL)
        XCTAssertEqual(store.dragSwap, DragSwapConfig.default)
        XCTAssertTrue(store.diagnosticsEnabled)
        XCTAssertFalse(store.dockReserveAllDisplays)
    }
}
