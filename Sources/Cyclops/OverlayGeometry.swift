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

  static func localFocusRects(
    globalFocusRects: [CGRect],
    screenFrame: CGRect,
    padding: CGFloat
  ) -> [CGRect] {
    globalFocusRects.compactMap {
      localFocusRect(globalFocusRect: $0, screenFrame: screenFrame, padding: padding)
    }
  }

  static let focusCornerRadius: CGFloat = 10

  /// The merged outline of every focus area, so overlapping windows form one clear region.
  static func focusOutline(focusRects: [CGRect]) -> CGPath? {
    let shapes = focusRects.map {
      CGPath(
        roundedRect: $0,
        cornerWidth: focusCornerRadius,
        cornerHeight: focusCornerRadius,
        transform: nil
      )
    }
    guard let first = shapes.first else { return nil }
    return shapes.dropFirst().reduce(first) { $0.union($1) }
  }

  /// An even-odd mask that covers `bounds` except for the focus areas.
  static func maskPath(bounds: CGRect, focusRects: [CGRect]) -> CGPath {
    let path = CGMutablePath()
    path.addRect(bounds)
    if let outline = focusOutline(focusRects: focusRects) {
      path.addPath(outline)
    }
    return path
  }

  /// Only a single focus area moving between windows animates; other changes snap.
  static func shouldAnimate(from oldRects: [CGRect], to newRects: [CGRect]) -> Bool {
    oldRects.count == 1 && newRects.count == 1 && oldRects != newRects
  }
}
