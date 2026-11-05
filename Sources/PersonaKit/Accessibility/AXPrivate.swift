import ApplicationServices
import CoreGraphics
import Foundation

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ outID: UnsafeMutablePointer<CGWindowID>) -> AXError

public enum AXPrivate {
    /// Extracts the `CGWindowID` from an `AXUIElement`, using private SPI with fallback to window-list frame matching.
    public static func windowID(for element: AXUIElement) -> CGWindowID? {
        var wid: CGWindowID = 0
        let status = _AXUIElementGetWindow(element, &wid)
        if status == .success, wid != 0 {
            return wid
        }

        // Fallback: match element bounds and PID against CGWindowListCopyWindowInfo
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid > 0 else {
            return nil
        }

        guard let position = copyPointAttribute(element: element, attribute: kAXPositionAttribute),
              let size = copySizeAttribute(element: element, attribute: kAXSizeAttribute) else {
            return nil
        }
        let axRect = CGRect(origin: position, size: size)

        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for info in windowInfoList {
            guard let wPid = info[kCGWindowOwnerPID as String] as? pid_t, wPid == pid else { continue }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }

            if abs(bounds.minX - axRect.minX) <= 2 &&
               abs(bounds.minY - axRect.minY) <= 2 &&
               abs(bounds.width - axRect.width) <= 4 &&
               abs(bounds.height - axRect.height) <= 4 {
                if let matchedID = info[kCGWindowNumber as String] as? CGWindowID {
                    return matchedID
                }
            }
        }

        return nil
    }

    public static func copyPointAttribute(element: AXUIElement, attribute: String) -> CGPoint? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success,
              let value = valueRef,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    public static func copySizeAttribute(element: AXUIElement, attribute: String) -> CGSize? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success,
              let value = valueRef,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    public static func copyStringAttribute(element: AXUIElement, attribute: String) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success,
              let str = valueRef as? String else {
            return nil
        }
        return str
    }
}
