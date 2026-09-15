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

            let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            if let axWindow = buildAXWindow(pid: pid, id: id, bundleID: bundleID, bounds: cgBounds) {
                if !axWindow.isMinimized && !axWindow.isFullscreen {
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

    private static func buildAXWindow(pid: pid_t, id: CGWindowID, bundleID: String?, bounds: CGRect) -> AXWindow? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return nil }

        for window in windows {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
            guard let pos = posRef, let size = sizeRef else { continue }

            var point = CGPoint.zero
            var sz = CGSize.zero
            AXValueGetValue(pos as! AXValue, .cgPoint, &point)
            AXValueGetValue(size as! AXValue, .cgSize, &sz)
            let axFrame = CGRect(origin: point, size: sz)

            if rectsApproxEqual(axFrame, bounds, tolerance: 2) {
                // A dialog, sheet, inspector or floating palette is on screen
                // at layer 0 just like a real window, but it is not something
                // the user arranges. Tiling it consumed a slot and pushed a
                // genuine window into `toMinimize`. See `WindowSubrole`.
                guard WindowSubrole.isTileable(subrole(of: window)) else { return nil }
                return AXWindow(element: window, id: id, pid: pid, bundleID: bundleID)
            }
        }
        return nil
    }

    private static func subrole(of element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &ref) == .success
        else { return nil }
        return ref as? String
    }
}
