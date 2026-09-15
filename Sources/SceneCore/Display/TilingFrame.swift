import AppKit
import CoreGraphics

/// Per-edge gap between a screen's `frame` and its `visibleFrame`, in points.
///
/// On macOS only two things create these gaps: the menu bar (top) and the Dock
/// (left, bottom, or right — never top).
public struct ScreenInsets: Equatable, Sendable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    /// Negative results are clamped to zero — a `visibleFrame` larger than its
    /// `frame` is nonsense, and letting it through would inflate the tiling
    /// rect past the physical screen.
    public init(frame: CGRect, visibleFrame: CGRect) {
        self.init(
            top: max(0, frame.maxY - visibleFrame.maxY),
            left: max(0, visibleFrame.minX - frame.minX),
            bottom: max(0, visibleFrame.minY - frame.minY),
            right: max(0, frame.maxX - visibleFrame.maxX)
        )
    }
}

/// The rect Scene tiles into. Replaces raw `NSScreen.visibleFrame` for all
/// layout math.
///
/// **Why not `visibleFrame` directly.** `visibleFrame` reserves Dock space only
/// on the display the Dock *currently* occupies, and the Dock is not pinned to
/// a display — it hops to whichever screen the pointer last touched the edge
/// of. That makes `visibleFrame` a function of the screen *and recent mouse
/// history*, so applying the same layout twice on the same screen could target
/// rects ~70pt apart. Every window then resized and shifted, and
/// `LayoutEngine`'s sticky pass (10pt tolerance) could not recognize windows
/// that were already in position.
///
/// **The fix.** Reserve the Dock's thickness uniformly on *every* screen.
/// Because the Dock sits on exactly one display at a time, the maximum
/// left/bottom/right inset across all screens *is* the Dock's thickness, and it
/// stays constant as the Dock moves. The top inset stays per-screen: the menu
/// bar does not follow the pointer, so a display without one must not surrender
/// 25pt to a display that has one.
///
/// The trade-off: on a multi-display setup the screen the Dock is *not* on
/// gives up the Dock strip. That is the price of "re-apply never moves
/// anything". Single-display users see no change at all — the maximum over one
/// screen is that screen's own inset, so the result equals `visibleFrame`
/// exactly.
///
/// Users who would rather have windows flush against the bottom edge can turn
/// the unified reserve off via `SettingsStore.dockReserveAllDisplays`, which
/// flows in as `reserveDockOnAllDisplays` and restores raw `visibleFrame`
/// behaviour — roaming Dock and all.
public enum TilingFrame {
    /// AppKit entry point. Reads the live screen list.
    ///
    /// Left non-isolated to match `ScreenResolver` — it is called from the
    /// `visibleFrameOverride` closures on `DragSwapController` /
    /// `SeamResizeController`, which are not `@MainActor`-annotated.
    public static func forScreen(_ screen: NSScreen, reserveDockOnAllDisplays: Bool = true) -> CGRect {
        forScreen(screen, screens: NSScreen.screens,
                  reserveDockOnAllDisplays: reserveDockOnAllDisplays)
    }

    /// Injectable variant — `screens` is the full arrangement the Dock could be
    /// sitting on.
    public static func forScreen(
        _ screen: NSScreen,
        screens: [NSScreen],
        reserveDockOnAllDisplays: Bool = true
    ) -> CGRect {
        let own = ScreenInsets(frame: screen.frame, visibleFrame: screen.visibleFrame)
        let all = screens.map { ScreenInsets(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        return compute(frame: screen.frame, ownInsets: own, allInsets: all,
                       reserveDockOnAllDisplays: reserveDockOnAllDisplays)
    }

    /// Pure core, unit-testable without `NSScreen`.
    ///
    /// Falls back to this screen's own `visibleFrame` if unifying the insets
    /// would produce a degenerate rect — e.g. a small external display sitting
    /// next to one whose insets are wider than the small display itself.
    public static func compute(
        frame: CGRect,
        ownInsets: ScreenInsets,
        allInsets: [ScreenInsets],
        reserveDockOnAllDisplays: Bool = true
    ) -> CGRect {
        let ownFrame = inset(frame, by: ownInsets)
        guard !allInsets.isEmpty else { return ownFrame }
        // Opted out: fall back to this screen's own `visibleFrame`. Windows
        // reach the bottom edge on a display the Dock is not on, at the cost
        // of the re-apply stability the unified reserve buys. Single-display
        // setups are identical either way — the maximum over one screen is
        // that screen's own inset.
        guard reserveDockOnAllDisplays else { return ownFrame }

        let unified = ScreenInsets(
            // Menu bar — does not hop with the pointer, so keep this screen's own.
            top: ownInsets.top,
            // Dock — may sit on any vertical or bottom edge, on any display.
            left: allInsets.map(\.left).max() ?? ownInsets.left,
            bottom: allInsets.map(\.bottom).max() ?? ownInsets.bottom,
            right: allInsets.map(\.right).max() ?? ownInsets.right
        )
        let result = inset(frame, by: unified)
        // `CGRect.width` / `.height` standardize to absolute values, so they
        // report a negative-size rect as positive. Test `size` directly.
        guard result.size.width > 0, result.size.height > 0 else { return ownFrame }
        return result
    }

    private static func inset(_ frame: CGRect, by i: ScreenInsets) -> CGRect {
        CGRect(
            x: frame.minX + i.left,
            y: frame.minY + i.bottom,
            width: frame.width - i.left - i.right,
            height: frame.height - i.top - i.bottom
        )
    }
}
