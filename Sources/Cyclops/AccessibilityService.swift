import AppKit
import ApplicationServices

enum FocusLookupResult {
  case window(CGRect)
  case cyclopsIsFrontmost
  case noWindow
}

struct AccessibilityService {
  var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  @discardableResult
  func requestPermission() -> Bool {
    AXIsProcessTrustedWithOptions(
      ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    )
  }

  func focusedWindow(excludingPID ownPID: pid_t) -> FocusLookupResult {
    let systemWideElement = AXUIElementCreateSystemWide()
    guard
      let application = elementAttribute(
        kAXFocusedApplicationAttribute,
        from: systemWideElement
      )
    else {
      return .noWindow
    }

    var focusedPID: pid_t = 0
    guard AXUIElementGetPid(application, &focusedPID) == .success else {
      return .noWindow
    }

    if focusedPID == ownPID {
      return .cyclopsIsFrontmost
    }

    guard
      let window = elementAttribute(kAXFocusedWindowAttribute, from: application),
      let position = pointAttribute(kAXPositionAttribute, from: window),
      let size = sizeAttribute(kAXSizeAttribute, from: window),
      size.width > 1,
      size.height > 1
    else {
      return .noWindow
    }

    let accessibilityRect = CGRect(origin: position, size: size)
    let primaryScreenMaxY = NSScreen.screens.first?.frame.maxY ?? 0
    return .window(
      CoordinateConverter.appKitRect(
        fromAccessibilityRect: accessibilityRect,
        primaryScreenMaxY: primaryScreenMaxY
      )
    )
  }

  private func elementAttribute(
    _ attribute: String,
    from element: AXUIElement
  ) -> AXUIElement? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      element,
      attribute as CFString,
      &value
    )
    guard
      result == .success,
      let value,
      CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    return (value as! AXUIElement)
  }

  private func pointAttribute(
    _ attribute: String,
    from element: AXUIElement
  ) -> CGPoint? {
    guard let value = axValueAttribute(attribute, from: element) else {
      return nil
    }

    var point = CGPoint.zero
    guard AXValueGetType(value) == .cgPoint,
      AXValueGetValue(value, .cgPoint, &point)
    else {
      return nil
    }
    return point
  }

  private func sizeAttribute(
    _ attribute: String,
    from element: AXUIElement
  ) -> CGSize? {
    guard let value = axValueAttribute(attribute, from: element) else {
      return nil
    }

    var size = CGSize.zero
    guard AXValueGetType(value) == .cgSize,
      AXValueGetValue(value, .cgSize, &size)
    else {
      return nil
    }
    return size
  }

  private func axValueAttribute(
    _ attribute: String,
    from element: AXUIElement
  ) -> AXValue? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      element,
      attribute as CFString,
      &value
    )
    guard
      result == .success,
      let value,
      CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    return (value as! AXValue)
  }
}
