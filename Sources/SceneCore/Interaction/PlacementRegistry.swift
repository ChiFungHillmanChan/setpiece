import CoreGraphics
import Foundation

/// One display's most recent successful layout fire — what drag-swap and seam
/// reflow need to act on that display's tiled windows.
public struct PlacementSnapshot {
    public let layout: Layout
    /// V0.6: the full `CustomLayout`, so `SeamResizeController` can read
    /// `template` + `slotProportions` (the derived `Layout.slots` alone can't
    /// be reversed back to proportions without template context).
    public let customLayout: CustomLayout
    public internal(set) var windows: [any WindowRef]
    /// Placements carry their slot index explicitly (sticky re-apply can leave
    /// gaps, e.g. slots {0, 2, 3} claimed), so never infer the slot from array
    /// position. `DragSwapController.finishDrag` uses this to recover the
    /// dragged window's original slot without trusting AX-live `frame`.
    public internal(set) var windowToSlotIdx: [CGWindowID: Int]
    /// The rect the layout was tiled into, and the display's frame at the
    /// time. Drags measure against `tilingFrame` so a Dock hop after the apply
    /// cannot make them snap to differently sized slots.
    public let tilingFrame: CGRect
    public let screenFrame: CGRect

    public init(
        layout: Layout,
        customLayout: CustomLayout,
        windows: [any WindowRef],
        windowToSlotIdx: [CGWindowID: Int],
        tilingFrame: CGRect,
        screenFrame: CGRect
    ) {
        self.layout = layout
        self.customLayout = customLayout
        self.windows = windows
        self.windowToSlotIdx = windowToSlotIdx
        self.tilingFrame = tilingFrame
        self.screenFrame = screenFrame
    }
}

/// Per-display record of which windows each display's last layout fire placed
/// in which slot.
///
/// Replaces a single global snapshot, which caused two multi-display bugs:
/// applying a layout on display B switched drag-swap off on display A (A's
/// windows "went free"), and a window the user had moved to another display
/// stayed recorded in its old slot, so the next swap into that slot dragged it
/// back across. A window belongs to at most one display's record.
public final class PlacementRegistry {
    public private(set) var snapshots: [CGDirectDisplayID: PlacementSnapshot] = [:]

    public init() {}

    /// Every tiled window on every display — the set to observe for drags.
    public var observedWindowIDs: Set<CGWindowID> {
        Set(snapshots.values.flatMap { $0.windowToSlotIdx.keys })
    }

    /// Replace `displayID`'s record after a successful layout fire. Windows it
    /// placed leave any other display's record, and displays missing from
    /// `liveDisplays` (unplugged since their layout was applied) are dropped.
    public func record(
        _ snapshot: PlacementSnapshot,
        on displayID: CGDirectDisplayID,
        liveDisplays: Set<CGDirectDisplayID>
    ) {
        let placed = Set(snapshot.windowToSlotIdx.keys)
        for other in Array(snapshots.keys) where other != displayID {
            remove(placed, from: other)
        }
        for stale in Array(snapshots.keys) where !liveDisplays.contains(stale) {
            snapshots[stale] = nil
        }
        snapshots[displayID] = placed.isEmpty ? nil : snapshot
    }

    public func snapshot(holding windowID: CGWindowID) -> (displayID: CGDirectDisplayID, snapshot: PlacementSnapshot)? {
        guard let entry = snapshots.first(where: { $0.value.windowToSlotIdx[windowID] != nil }) else { return nil }
        return (entry.key, entry.value)
    }

    /// Slot changes from a drag-swap, applied to whichever display holds each
    /// window. Keeps consecutive swaps (and seam reflow, which reads the same
    /// map) working from current positions.
    public func applySlotUpdates(_ updates: [CGWindowID: Int]) {
        for (id, slot) in updates {
            guard let key = snapshot(holding: id)?.displayID else { continue }
            snapshots[key]?.windowToSlotIdx[id] = slot
        }
    }

    /// Windows that left their layout's display. A display left with nothing
    /// tiled loses its record.
    public func forget(_ ids: Set<CGWindowID>) {
        for key in Array(snapshots.keys) {
            remove(ids, from: key)
        }
    }

    public func removeAll() {
        snapshots.removeAll()
    }

    private func remove(_ ids: Set<CGWindowID>, from key: CGDirectDisplayID) {
        guard var snap = snapshots[key] else { return }
        snap.windows.removeAll { ids.contains($0.id) }
        for id in ids { snap.windowToSlotIdx[id] = nil }
        snapshots[key] = snap.windowToSlotIdx.isEmpty ? nil : snap
    }
}
