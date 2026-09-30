import CoreGraphics
import Foundation

/// Windows the user asked to keep clear alongside the selected window, in pin order.
struct PinnedWindows<Window: Equatable> {
  private(set) var windows: [Window] = []

  var isEmpty: Bool { windows.isEmpty }
  var count: Int { windows.count }

  /// Pins `window`, or unpins it if it is already pinned. Returns whether it is now pinned.
  @discardableResult
  mutating func toggle(_ window: Window) -> Bool {
    if let index = windows.firstIndex(of: window) {
      windows.remove(at: index)
      return false
    }
    windows.append(window)
    return true
  }

  mutating func remove(where shouldRemove: (Window) -> Bool) {
    windows.removeAll(where: shouldRemove)
  }

  mutating func unpinAll() {
    windows.removeAll()
  }
}

/// A regular window the window server reports as on screen in the current Space.
///
/// Only owner PIDs and bounds are read, which needs no Screen Recording access.
struct OnScreenWindow: Equatable {
  let pid: pid_t
  /// Global display coordinates with a top-left origin, the same space Accessibility uses.
  let frame: CGRect

  private static let frameTolerance: CGFloat = 1

  static func current() -> [OnScreenWindow] {
    let info =
      CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]] ?? []
    return parse(info)
  }

  static func parse(_ info: [[String: Any]]) -> [OnScreenWindow] {
    info.compactMap { entry in
      guard
        let pid = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
        (entry[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
        let boundsDictionary = entry[kCGWindowBounds as String] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
      else { return nil }
      return OnScreenWindow(pid: pid, frame: frame)
    }
  }

  static func isVisible(
    pid: pid_t,
    accessibilityFrame: CGRect,
    among windows: [OnScreenWindow]
  ) -> Bool {
    windows.contains { window in
      window.pid == pid
        && abs(window.frame.minX - accessibilityFrame.minX) <= frameTolerance
        && abs(window.frame.minY - accessibilityFrame.minY) <= frameTolerance
        && abs(window.frame.width - accessibilityFrame.width) <= frameTolerance
        && abs(window.frame.height - accessibilityFrame.height) <= frameTolerance
    }
  }
}
