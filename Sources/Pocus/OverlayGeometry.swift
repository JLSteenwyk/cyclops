import CoreGraphics

enum CoordinateConverter {
  static func appKitRect(
    fromAccessibilityRect rect: CGRect,
    primaryScreenMaxY: CGFloat
  ) -> CGRect {
    CGRect(
      x: rect.minX,
      y: primaryScreenMaxY - rect.maxY,
      width: rect.width,
      height: rect.height
    )
  }
}

enum OverlayGeometry {
  static func localFocusRect(
    globalFocusRect: CGRect,
    screenFrame: CGRect,
    padding: CGFloat
  ) -> CGRect? {
    let expandedFocusRect = globalFocusRect.insetBy(dx: -padding, dy: -padding)
    let intersection = expandedFocusRect.intersection(screenFrame)
    guard !intersection.isNull, !intersection.isEmpty else { return nil }

    return intersection.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
  }
}
