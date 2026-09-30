import AppKit

@MainActor
final class FocusOverlayPanel {
  private let panel: NSPanel
  private let overlayView: FocusOverlayView
  private let screenFrame: CGRect
  private var currentLocalFocusRects: [CGRect] = []

  init(screen: NSScreen) {
    screenFrame = screen.frame
    overlayView = FocusOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
    panel = NSPanel(
      contentRect: screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .none
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .fullScreenAuxiliary,
      .ignoresCycle,
    ]
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
    panel.contentView = overlayView
  }

  func update(
    globalFocusRects: [CGRect],
    padding: CGFloat,
    strength: BackdropStrength
  ) {
    let localFocusRects = OverlayGeometry.localFocusRects(
      globalFocusRects: globalFocusRects,
      screenFrame: screenFrame,
      padding: padding
    )

    let shouldAnimate = OverlayGeometry.shouldAnimate(
      from: currentLocalFocusRects,
      to: localFocusRects
    )
    currentLocalFocusRects = localFocusRects
    overlayView.update(
      focusRects: localFocusRects,
      strength: strength,
      animated: shouldAnimate
    )

    if !panel.isVisible {
      panel.orderFrontRegardless()
    }
  }

  func hide() {
    panel.orderOut(nil)
  }
}
