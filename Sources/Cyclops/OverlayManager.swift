import AppKit

@MainActor
final class OverlayManager {
  private var panels: [FocusOverlayPanel] = []

  func rebuild() {
    hide()
    panels = NSScreen.screens.map(FocusOverlayPanel.init(screen:))
  }

  func show(
    focusRects: [CGRect],
    padding: CGFloat,
    strength: BackdropStrength
  ) {
    if panels.count != NSScreen.screens.count {
      rebuild()
    }

    for panel in panels {
      panel.update(
        globalFocusRects: focusRects,
        padding: padding,
        strength: strength
      )
    }
  }

  func hide() {
    for panel in panels {
      panel.hide()
    }
  }
}
