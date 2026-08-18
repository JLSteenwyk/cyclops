import AppKit

@MainActor
final class FocusOverlayPanel: NSPanel {
  private let overlayView: FocusOverlayView
  private let screenFrame: CGRect
  private var currentLocalFocusRect: CGRect?

  init(screen: NSScreen) {
    screenFrame = screen.frame
    overlayView = FocusOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))

    super.init(
      contentRect: screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false,
      screen: screen
    )

    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = true
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .fullScreenAuxiliary,
      .ignoresCycle,
    ]
    level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
    contentView = overlayView
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

    if !isVisible {
      orderFrontRegardless()
    }
    return localFocusRect != nil
  }
}
