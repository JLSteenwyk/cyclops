import AppKit

@MainActor
final class FocusOverlayPanel {
  private let panel: NSPanel
  private let overlayView: FocusOverlayView
  private let screenFrame: CGRect
  private var currentLocalFocusRect: CGRect?

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

  @discardableResult
  func update(
    globalFocusRect: CGRect,
    padding: CGFloat,
    strength: BackdropStrength
  ) -> Bool {
    let localFocusRect = OverlayGeometry.localFocusRect(
      globalFocusRect: globalFocusRect,
      screenFrame: screenFrame,
      padding: padding
    )

    let shouldAnimate =
      currentLocalFocusRect != nil
      && currentLocalFocusRect != localFocusRect
    currentLocalFocusRect = localFocusRect
    overlayView.update(
      focusRect: localFocusRect,
      strength: strength,
      animated: shouldAnimate
    )

    if !panel.isVisible {
      panel.orderFrontRegardless()
    }
    return localFocusRect != nil
  }

  func hide() {
    panel.orderOut(nil)
  }
}
