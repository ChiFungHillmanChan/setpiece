import CoreGraphics
import os

public enum LayoutEngine {
    /// Maps windows to slots. Windows whose frame already sits on a slot rect
    /// (within `stickyTolerance` points) keep that slot — re-applying a layout
    /// must not reshuffle windows that are already in position. Remaining
    /// windows fill the remaining slots in z-order; leftovers get minimized.
    /// A sticky window's placement targets the slot's exact rect, so
    /// sub-tolerance drift self-heals on re-apply.
    ///
    /// `alternateFrames` are other rects the same layout may have been tiled
    /// into earlier — in practice this display with and without the Dock's
    /// strip (`TilingFrame.stickyCandidates`). A window matching a slot in any
    /// of them keeps that slot and is stretched to `visibleFrame`'s rect, so a
    /// re-apply after the Dock hops displays never reshuffles windows. Matches
    /// against `visibleFrame` itself are claimed first.
    public static func plan(
        windows: [any WindowRef],
        visibleFrame: CGRect,
        layout: Layout,
        stickyTolerance: CGFloat = 10,
        alternateFrames: [CGRect] = []
    ) -> Plan {
        let slotRects = layout.slots.map { $0.absoluteRect(in: visibleFrame) }
        let matchFrames = [visibleFrame] + alternateFrames.filter { $0 != visibleFrame }

        // Sticky pass — primary frame first, then alternates; z-order priority
        // when two windows sit on the same rect.
        var slotToWindow: [Int: any WindowRef] = [:]
        var stickyIDs = Set<CGWindowID>()
        for frame in matchFrames {
            let rects = layout.slots.map { $0.absoluteRect(in: frame) }
            for window in windows where !stickyIDs.contains(window.id) {
                let claimed = rects.indices.first { idx in
                    slotToWindow[idx] == nil &&
                    rectsApproxEqual(window.frame, rects[idx], tolerance: stickyTolerance)
                }
                if let idx = claimed {
                    slotToWindow[idx] = window
                    stickyIDs.insert(window.id)
                }
            }
        }

        // Fill pass — remaining windows (z-order) into remaining slots (index order).
        var overflow: [CGWindowID] = []
        var freeSlots = slotRects.indices.filter { slotToWindow[$0] == nil }[...]
        for window in windows where !stickyIDs.contains(window.id) {
            if let idx = freeSlots.popFirst() {
                slotToWindow[idx] = window
            } else {
                overflow.append(window.id)
            }
        }

        let placements = slotToWindow.keys.sorted().map { idx in
            Placement(
                windowID: slotToWindow[idx]!.id,
                targetFrame: slotRects[idx],
                slotIndex: idx
            )
        }
        return Plan(
            placements: placements,
            toMinimize: overflow,
            leftEmptySlotCount: slotRects.count - slotToWindow.count
        )
    }
}

private let layoutEngineLog = Logger(subsystem: "com.scene.core", category: "layout-engine")

extension LayoutEngine {
    public static func apply(
        _ plan: Plan,
        on windows: [any WindowRef],
        electronTolerancePx: CGFloat = 5
    ) throws -> Outcome {
        if plan.isEmpty { return .noWindows }

        var byID: [CGWindowID: any WindowRef] = [:]
        for w in windows { byID[w.id] = w }

        var placed = 0
        var failed = 0

        for p in plan.placements {
            guard let window = byID[p.windowID] else {
                failed += 1
                continue
            }
            do {
                try window.setFrame(p.targetFrame)
                if !rectsApproxEqual(window.frame, p.targetFrame, tolerance: electronTolerancePx) {
                    let dx = p.targetFrame.origin.x - window.frame.origin.x
                    let dy = p.targetFrame.origin.y - window.frame.origin.y
                    let dw = p.targetFrame.width - window.frame.width
                    let dh = p.targetFrame.height - window.frame.height
                    let corrected = CGRect(
                        x: p.targetFrame.origin.x + dx,
                        y: p.targetFrame.origin.y + dy,
                        width: p.targetFrame.width + dw,
                        height: p.targetFrame.height + dh
                    )
                    try window.setFrame(corrected)
                }
                placed += 1
            } catch {
                layoutEngineLog.error("setFrame failed for \(window.bundleID ?? "unknown", privacy: .public): \(String(describing: error), privacy: .public)")
                failed += 1
            }
        }

        var minimized = 0
        for wid in plan.toMinimize {
            guard let window = byID[wid] else { continue }
            do {
                try window.minimize()
                minimized += 1
            } catch {
                layoutEngineLog.error("minimize failed for \(wid): \(String(describing: error), privacy: .public)")
                failed += 1
            }
        }

        return .applied(
            placed: placed,
            minimized: minimized,
            leftEmpty: plan.leftEmptySlotCount,
            failed: failed
        )
    }
}
