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

    /// `subrole` is the raw `kAXSubroleAttribute` value, or `nil` when the
    /// window does not publish one.
    public static func isTileable(_ subrole: String?) -> Bool {
        guard let subrole else { return true }
        return !nonTileable.contains(subrole.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
