import XCTest
@testable import SceneCore

/// `scene://` predates the rename to Setpiece and is baked into Shortcuts,
/// Raycast scripts and bookmarks the app cannot see or migrate. Both schemes
/// are permanent; neither may be dropped.
///
/// `parse` returns a `Result` rather than throwing, so these assert on the
/// case — `try?` would be non-nil even for a rejected scheme.
final class URLRouterSchemeTests: XCTestCase {

    private func route(_ s: String) -> Result<AutomationCommand, URLRoutingError> {
        URLRouter.parse(URL(string: s)!)
    }

    func testTheOriginalSchemeStillRoutes() {
        guard case .success = route("scene://layout/Quads") else {
            return XCTFail("scene:// must never stop working")
        }
    }

    func testTheNewSchemeRoutes() {
        guard case .success = route("setpiece://layout/Quads") else {
            return XCTFail("setpiece:// should route")
        }
    }

    func testBothSchemesResolveToTheSameCommand() {
        XCTAssertEqual(route("scene://layout/Quads"), route("setpiece://layout/Quads"))
    }

    func testSchemeMatchIsCaseInsensitive() {
        guard case .success = route("SetPiece://layout/Quads") else {
            return XCTFail("mixed case setpiece:// should route")
        }
        guard case .success = route("SCENE://layout/Quads") else {
            return XCTFail("upper case scene:// should route")
        }
    }

    func testAnUnrelatedSchemeIsRejected() {
        XCTAssertEqual(route("https://layout/Quads"), .failure(.unsupportedScheme))
    }
}
