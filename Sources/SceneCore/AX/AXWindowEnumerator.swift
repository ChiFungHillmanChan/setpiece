import AppKit
import ApplicationServices
import CoreGraphics

public enum AXWindowEnumerator {
    public enum EnumerationError: Error {
        case permissionDenied
        case cgWindowListFailed
    }

    public static func listVisibleWindows(on screen: NSScreen) throws -> [AXWindow] {
        guard AXPermission.check() else { throw EnumerationError.permissionDenied }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw EnumerationError.cgWindowListFailed
        }

        var results: [AXWindow] = []
        var candidatesByPID: [pid_t: [AXWindowCandidate]] = [:]
        var claimedCandidateIndexesByPID: [pid_t: Set<Int>] = [:]
        for info in list {
            guard
                let id = info[kCGWindowNumber as String] as? CGWindowID,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0,
                let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                let cgBounds = boundsFromDict(boundsDict)
            else { continue }

            // Ownership test uses `frame`, not `visibleFrame`: a window whose
            // center happens to sit in the Dock strip still belongs to this
            // display, and `visibleFrame` would drop it from the plan entirely
            // — and drop it only while the Dock happened to be on this screen,
            // since the Dock follows the pointer. See `TilingFrame`.
            let centerTopLeft = CGPoint(x: cgBounds.midX, y: cgBounds.midY)
            guard screen.frame.contains(DisplayCoordinates.axToNS(centerTopLeft)) else { continue }

            let candidates: [AXWindowCandidate]
            if let cached = candidatesByPID[pid] {
                candidates = cached
            } else {
                candidates = windowCandidates(for: pid)
                candidatesByPID[pid] = candidates
            }

            let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            let claimedIndexes = claimedCandidateIndexesByPID[pid, default: []]
            if let match = buildAXWindow(
                id: id,
                pid: pid,
                bundleID: bundleID,
                bounds: cgBounds,
                candidates: candidates,
                claimedCandidateIndexes: claimedIndexes
            ) {
                let axWindow = match.window
                if !axWindow.isMinimized && !axWindow.isFullscreen {
                    claimedCandidateIndexesByPID[pid, default: []].insert(match.candidateIndex)
                    results.append(axWindow)
                }
            }
        }
        return results
    }

    // MARK: - private

    private static func boundsFromDict(_ dict: [String: CGFloat]) -> CGRect? {
        guard
            let x = dict["X"], let y = dict["Y"],
            let w = dict["Width"], let h = dict["Height"]
        else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Returns the first AX candidate that has the same frame as the CG window
    /// and has not already been paired with another CG window from this app.
    ///
    /// Multiple windows in one app commonly share a frame immediately after
    /// they are restored or unminimized. Reusing the first matching AX element
    /// for each CG window makes Scene move one window repeatedly while leaving
    /// its siblings in place.
    static func firstUnclaimedCandidateIndex(
        candidateFrames: [CGRect],
        matching targetFrame: CGRect,
        claimedIndexes: Set<Int>,
        tolerance: CGFloat = 2
    ) -> Int? {
        candidateFrames.indices.first { index in
            !claimedIndexes.contains(index) &&
            rectsApproxEqual(candidateFrames[index], targetFrame, tolerance: tolerance)
        }
    }

    private struct AXWindowCandidate {
        let element: AXUIElement
        let frame: CGRect
    }

    private static func windowCandidates(for pid: pid_t) -> [AXWindowCandidate] {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return [] }

        return windows.compactMap { window in
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
            guard let pos = posRef, let size = sizeRef else { return nil }

            var point = CGPoint.zero
            var sz = CGSize.zero
            AXValueGetValue(pos as! AXValue, .cgPoint, &point)
            AXValueGetValue(size as! AXValue, .cgSize, &sz)
            return AXWindowCandidate(element: window, frame: CGRect(origin: point, size: sz))
        }
    }

    private static func buildAXWindow(
        id: CGWindowID,
        pid: pid_t,
        bundleID: String?,
        bounds: CGRect,
        candidates: [AXWindowCandidate],
        claimedCandidateIndexes: Set<Int>
    ) -> (window: AXWindow, candidateIndex: Int)? {
        guard let candidateIndex = firstUnclaimedCandidateIndex(
            candidateFrames: candidates.map(\.frame),
            matching: bounds,
            claimedIndexes: claimedCandidateIndexes
        ) else { return nil }

        return (
            AXWindow(element: candidates[candidateIndex].element, id: id, pid: pid, bundleID: bundleID),
            candidateIndex
        )
    }
}
