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
/// **The Dock roams.** `visibleFrame` reserves Dock space only on the display
/// the Dock *currently* occupies, and the Dock hops to whichever screen the
/// pointer last touched the edge of. So the same layout applied twice on the
/// same screen can target rects ~70pt apart.
///
/// **Default (V0.8.2): reserve only where the Dock is.** Each display uses its
/// own `visibleFrame`, so a display without the Dock tiles to its bottom edge.
/// Re-apply stability comes from `stickyCandidates`: `LayoutEngine.plan`
/// recognises a window tiled under the with-Dock or without-Dock frame and
/// keeps it in its slot, only stretching it to today's rect.
///
/// **Opt-in: reserve on every display** (`reserveDockOnAllDisplays: true`,
/// V0.7.4's behaviour). Because the Dock sits on exactly one display at a
/// time, the maximum left/bottom/right inset across all screens *is* the
/// Dock's thickness, and it stays constant as the Dock moves. The top inset
/// stays per-screen: the menu bar does not follow the pointer. The cost is a
/// dead strip on every display the Dock is not on; the gain is that the Dock
/// never covers a tiled window when it hops over.
///
/// Single-display users see no difference either way — the maximum over one
/// screen is that screen's own inset.
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

    /// AppKit entry point for `stickyCandidates(frame:ownInsets:allInsets:)`.
    public static func stickyCandidates(for screen: NSScreen) -> [CGRect] {
        stickyCandidates(
            frame: screen.frame,
            ownInsets: ScreenInsets(frame: screen.frame, visibleFrame: screen.visibleFrame),
            allInsets: NSScreen.screens.map { ScreenInsets(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        )
    }

    /// Every rect a layout on this display could have been tiled into as the
    /// Dock roams: its current `visibleFrame`, the frame with the Dock's strip
    /// reserved, and the frame with no Dock at all. Identical rects are listed
    /// once.
    ///
    /// `LayoutEngine.plan` takes these as `alternateFrames` so a window that
    /// was tiled before the Dock hopped still counts as sitting in its slot.
    /// That is what lets a Dockless display use its full height without a
    /// re-apply reshuffling windows whenever the Dock moves.
    public static func stickyCandidates(
        frame: CGRect,
        ownInsets: ScreenInsets,
        allInsets: [ScreenInsets]
    ) -> [CGRect] {
        let withDock = compute(frame: frame, ownInsets: ownInsets, allInsets: allInsets,
                               reserveDockOnAllDisplays: true)
        let noDock = inset(frame, by: ScreenInsets(top: ownInsets.top, left: 0, bottom: 0, right: 0))
        var result: [CGRect] = []
        for rect in [inset(frame, by: ownInsets), withDock, noDock] where !result.contains(rect) {
            result.append(rect)
        }
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
