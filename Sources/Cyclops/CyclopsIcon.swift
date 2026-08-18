import AppKit

enum CyclopsIcon {
  @MainActor
  static func statusImage() -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      NSGraphicsContext.current?.shouldAntialias = true
      NSColor.black.setStroke()
      NSColor.black.setFill()

      let eye = NSBezierPath()
      eye.move(to: NSPoint(x: rect.minX + 1, y: rect.midY))
      eye.curve(
        to: NSPoint(x: rect.maxX - 1, y: rect.midY),
        controlPoint1: NSPoint(x: rect.minX + 5, y: rect.maxY - 2.5),
        controlPoint2: NSPoint(x: rect.maxX - 5, y: rect.maxY - 2.5)
      )
      eye.curve(
        to: NSPoint(x: rect.minX + 1, y: rect.midY),
        controlPoint1: NSPoint(x: rect.maxX - 5, y: rect.minY + 2.5),
        controlPoint2: NSPoint(x: rect.minX + 5, y: rect.minY + 2.5)
      )
      eye.lineWidth = 1.6
      eye.lineCapStyle = .round
      eye.lineJoinStyle = .round
      eye.stroke()

      let irisRect = NSRect(x: rect.midX - 3.6, y: rect.midY - 3.6, width: 7.2, height: 7.2)
      let iris = NSBezierPath(ovalIn: irisRect)
      iris.lineWidth = 1.25
      iris.stroke()

      let pupilRect = NSRect(x: rect.midX - 1, y: rect.midY - 3, width: 2, height: 6)
      NSBezierPath(roundedRect: pupilRect, xRadius: 1, yRadius: 1).fill()
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Cyclops"
    return image
  }
}
