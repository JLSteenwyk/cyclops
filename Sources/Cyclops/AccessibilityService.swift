import AppKit
import ApplicationServices

struct TrackedWindow: Equatable {
  let element: AXUIElement
  let pid: pid_t
}

struct FocusedWindow {
  let window: TrackedWindow
  /// AppKit global coordinates.
  let frame: CGRect
}

enum FocusLookupResult {
  case window(FocusedWindow)
  case cyclopsIsFrontmost
  case noWindow
}

enum PinnedWindowState: Equatable {
  /// On screen in the current Space, in AppKit global coordinates.
  case visible(CGRect)
  /// Still open but minimized, hidden, or on another Space.
  case hidden
  case closed
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
      let accessibilityRect = accessibilityFrame(of: window),
      accessibilityRect.width > 1,
      accessibilityRect.height > 1
    else {
      return .noWindow
    }

    return .window(
      FocusedWindow(
        window: TrackedWindow(element: window, pid: focusedPID),
        frame: appKitRect(fromAccessibilityRect: accessibilityRect)
      )
    )
  }

  func state(
    of window: TrackedWindow,
    onScreenWindows: [OnScreenWindow]
  ) -> PinnedWindowState {
    var minimized: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      window.element,
      kAXMinimizedAttribute as CFString,
      &minimized
    )
    // Only a destroyed element means the window closed; a busy app can fail other reads.
    guard result != .invalidUIElement else { return .closed }

    guard
      (minimized as? Bool) != true,
      let accessibilityRect = accessibilityFrame(of: window.element),
      OnScreenWindow.isVisible(
        pid: window.pid,
        accessibilityFrame: accessibilityRect,
        among: onScreenWindows
      )
    else {
      return .hidden
    }
    return .visible(appKitRect(fromAccessibilityRect: accessibilityRect))
  }

  private func accessibilityFrame(of window: AXUIElement) -> CGRect? {
    guard
      let position = pointAttribute(kAXPositionAttribute, from: window),
      let size = sizeAttribute(kAXSizeAttribute, from: window)
    else { return nil }
    return CGRect(origin: position, size: size)
  }

  private func appKitRect(fromAccessibilityRect rect: CGRect) -> CGRect {
    CoordinateConverter.appKitRect(
      fromAccessibilityRect: rect,
      primaryScreenMaxY: NSScreen.screens.first?.frame.maxY ?? 0
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
