import XCTest
@testable import SceneCore

final class WindowSubroleTests: XCTestCase {

    // MARK: - what a layout should tile

    func testStandardWindowIsTileable() {
        XCTAssertTrue(WindowSubrole.isTileable("AXStandardWindow"))
    }

    /// Not every app fills in a subrole. Excluding those would silently stop
    /// tiling whole apps, which is a far worse failure than tiling one stray
    /// panel, so a missing subrole is treated as an ordinary window.
    func testMissingSubroleIsTileable() {
        XCTAssertTrue(WindowSubrole.isTileable(nil))
    }

    func testEmptySubroleIsTileable() {
        XCTAssertTrue(WindowSubrole.isTileable(""))
    }

    /// Same reasoning as a missing subrole: deny-list, never allow-list, so a
    /// subrole this build has never heard of cannot break an app's tiling.
    func testUnrecognizedSubroleIsTileable() {
        XCTAssertTrue(WindowSubrole.isTileable("AXSomeFutureWindowKind"))
    }

    // MARK: - what it must not tile

    func testDialogIsNotTileable() {
        XCTAssertFalse(WindowSubrole.isTileable("AXDialog"))
    }

    func testSystemDialogIsNotTileable() {
        XCTAssertFalse(WindowSubrole.isTileable("AXSystemDialog"))
    }

    func testFloatingWindowIsNotTileable() {
        XCTAssertFalse(WindowSubrole.isTileable("AXFloatingWindow"))
    }

    func testSystemFloatingWindowIsNotTileable() {
        XCTAssertFalse(WindowSubrole.isTileable("AXSystemFloatingWindow"))
    }

    func testSheetIsNotTileable() {
        XCTAssertFalse(WindowSubrole.isTileable("AXSheet"))
    }

    func testDrawerIsNotTileable() {
        XCTAssertFalse(WindowSubrole.isTileable("AXDrawer"))
    }

    /// `AXUnknown` means "the app did not classify this", which is ambiguous,
    /// not disqualifying. Rejecting it risks silently un-tiling a whole app,
    /// and layer-0 filtering already discards the overlays that usually carry
    /// it — so it stays tileable.
    func testUnknownIsTileable() {
        XCTAssertTrue(WindowSubrole.isTileable("AXUnknown"))
    }

    // MARK: - robustness

    /// AX string values have been observed with stray whitespace; a dialog must
    /// not slip through because of it.
    func testSubroleIsMatchedIgnoringSurroundingWhitespace() {
        XCTAssertFalse(WindowSubrole.isTileable("  AXDialog  "))
    }

    // MARK: - mislabelled main windows

    /// WhatsApp's main window reports `AXDialog`, yet it has working minimize,
    /// zoom and full-screen buttons like any document window. Skipping it left
    /// it floating on top of the freshly tiled windows.
    func testDialogWithFullDocumentChromeIsTileable() {
        let chrome = WindowChrome(minimizeEnabled: true, zoomEnabled: true, fullScreenEnabled: true)
        XCTAssertTrue(WindowSubrole.isTileable("AXDialog", chrome: chrome))
    }

    /// The full-screen button alone is enough: macOS only enables it on
    /// windows that can be a primary full-screen window.
    func testFloatingWindowWithFullScreenButtonIsTileable() {
        let chrome = WindowChrome(minimizeEnabled: false, zoomEnabled: false, fullScreenEnabled: true)
        XCTAssertTrue(WindowSubrole.isTileable("AXFloatingWindow", chrome: chrome))
    }

    func testDialogThatCanMinimizeAndZoomIsTileable() {
        let chrome = WindowChrome(minimizeEnabled: true, zoomEnabled: true, fullScreenEnabled: false)
        XCTAssertTrue(WindowSubrole.isTileable("AXDialog", chrome: chrome))
    }

    /// An alert or About box: close button only.
    func testDialogWithoutDocumentChromeIsNotTileable() {
        let chrome = WindowChrome(minimizeEnabled: false, zoomEnabled: false, fullScreenEnabled: false)
        XCTAssertFalse(WindowSubrole.isTileable("AXDialog", chrome: chrome))
    }

    /// A resizable utility panel can zoom but not minimize — still a panel.
    func testDialogThatCanOnlyZoomIsNotTileable() {
        let chrome = WindowChrome(minimizeEnabled: false, zoomEnabled: true, fullScreenEnabled: false)
        XCTAssertFalse(WindowSubrole.isTileable("AXDialog", chrome: chrome))
    }

    /// Sheets and drawers hang off a parent window and cannot be positioned on
    /// their own, whatever buttons they report.
    func testSheetIsNeverTileableEvenWithDocumentChrome() {
        let chrome = WindowChrome(minimizeEnabled: true, zoomEnabled: true, fullScreenEnabled: true)
        XCTAssertFalse(WindowSubrole.isTileable("AXSheet", chrome: chrome))
        XCTAssertFalse(WindowSubrole.isTileable("AXDrawer", chrome: chrome))
    }

    func testStandardWindowStaysTileableWithoutChrome() {
        let chrome = WindowChrome(minimizeEnabled: false, zoomEnabled: false, fullScreenEnabled: false)
        XCTAssertTrue(WindowSubrole.isTileable("AXStandardWindow", chrome: chrome))
    }
}
