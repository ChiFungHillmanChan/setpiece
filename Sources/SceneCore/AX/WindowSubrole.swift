import Foundation

/// Decides whether an accessibility window is the kind of window a layout
/// should tile.
///
/// `CGWindowListCopyWindowInfo` at layer 0 returns every on-screen window an
/// app owns, which includes its dialogs, sheets, inspectors and floating
/// palettes. Before this test each of those consumed a slot, so opening a
/// preferences dialog or an inspector re-shuffled the whole layout and pushed
/// a real window into `toMinimize`.
///
/// **Deny-list, never allow-list.** Plenty of apps leave `AXSubrole` unset or
/// report something bespoke, and refusing to tile those would silently break
/// tiling for an entire app — a much worse outcome than tiling one stray
/// panel. Only subroles that are unambiguously not user-tileable are rejected.
///
/// `AXUnknown` is deliberately *not* on the list. It means "the app did not say
/// what this is", which is ambiguous rather than disqualifying, and the layer-0
/// test in `AXWindowEnumerator` already discards the overlay windows that
/// usually carry it.
/// The title-bar buttons a window exposes, each `true` only when the button
/// exists *and* is enabled. Read from `kAXMinimizeButtonAttribute`,
/// `kAXZoomButtonAttribute` and `kAXFullScreenButtonAttribute`.
public struct WindowChrome: Equatable, Sendable {
    public let minimizeEnabled: Bool
    public let zoomEnabled: Bool
    public let fullScreenEnabled: Bool

    public init(minimizeEnabled: Bool, zoomEnabled: Bool, fullScreenEnabled: Bool) {
        self.minimizeEnabled = minimizeEnabled
        self.zoomEnabled = zoomEnabled
        self.fullScreenEnabled = fullScreenEnabled
    }

    /// What a document window carries and a dialog or palette does not.
    /// macOS only enables the full-screen button on windows that can be a
    /// primary full-screen window; a panel that can both minimize and zoom is
    /// a resizable, Dock-able window in everything but its label.
    var looksLikeDocumentWindow: Bool {
        fullScreenEnabled || (minimizeEnabled && zoomEnabled)
    }
}

public enum WindowSubrole {
    /// Subroles that are never a window the user arranges. `AXSheet` and
    /// `AXDrawer` are attached to a parent window and cannot be positioned
    /// independently at all.
    public static let nonTileable: Set<String> = [
        "AXDialog",
        "AXSystemDialog",
        "AXFloatingWindow",
        "AXSystemFloatingWindow",
        "AXSheet",
        "AXDrawer",
    ]

    /// Attached to a parent window and cannot be positioned on their own, so
    /// no amount of window chrome makes them tileable.
    static let attachedToParent: Set<String> = ["AXSheet", "AXDrawer"]

    /// `subrole` is the raw `kAXSubroleAttribute` value, or `nil` when the
    /// window does not publish one.
    ///
    /// `chrome` rescues main windows that mislabel themselves. WhatsApp's
    /// reports `AXDialog` while carrying working minimize, zoom and full-screen
    /// buttons; trusting the label alone left it floating on top of every
    /// layout. Pass `nil` when the buttons could not be read, which keeps the
    /// label's verdict.
    public static func isTileable(_ subrole: String?, chrome: WindowChrome? = nil) -> Bool {
        guard let subrole else { return true }
        let trimmed = subrole.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nonTileable.contains(trimmed) else { return true }
        if attachedToParent.contains(trimmed) { return false }
        return chrome?.looksLikeDocumentWindow ?? false
    }
}
