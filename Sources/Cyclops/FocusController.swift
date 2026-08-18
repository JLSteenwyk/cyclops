import AppKit

@MainActor
final class FocusController: NSObject {
  private let accessibility: AccessibilityService
  private let settings: CyclopsSettings
  private let overlays = OverlayManager()
  private var refreshTimer: Timer?
  private var lastFocusedWindowFrame: CGRect?

  private(set) var isPaused = false
  var onStateChange: (() -> Void)?

  init(accessibility: AccessibilityService, settings: CyclopsSettings) {
    self.accessibility = accessibility
    self.settings = settings
    super.init()
  }

  func start() {
    overlays.rebuild()

    let timer = Timer(
      timeInterval: 0.12,
      target: self,
      selector: #selector(refresh),
      userInfo: nil,
      repeats: true
    )
    timer.tolerance = 0.03
    RunLoop.main.add(timer, forMode: .common)
    refreshTimer = timer

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screensDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )

    refresh()
  }

  func togglePaused() {
    isPaused.toggle()
    if isPaused {
      overlays.hide()
    } else {
      refresh()
    }
    onStateChange?()
  }

  func setStrength(_ strength: BackdropStrength) {
    settings.strength = strength
    refreshUsingLastFrame()
    onStateChange?()
  }

  func setPadding(_ padding: CGFloat) {
    settings.padding = padding
    refreshUsingLastFrame()
    onStateChange?()
  }

  var strength: BackdropStrength { settings.strength }
  var padding: CGFloat { settings.padding }

  @objc private func refresh() {
    guard !isPaused, accessibility.isTrusted else {
      overlays.hide()
      return
    }

    switch accessibility.focusedWindow(excludingPID: ProcessInfo.processInfo.processIdentifier) {
    case .window(let frame):
      lastFocusedWindowFrame = frame
      overlays.show(
        focusedWindowFrame: frame,
        padding: settings.padding,
        strength: settings.strength
      )
    case .cyclopsIsFrontmost:
      refreshUsingLastFrame()
    case .noWindow:
      lastFocusedWindowFrame = nil
      overlays.hide()
    }
  }

  private func refreshUsingLastFrame() {
    guard !isPaused, let lastFocusedWindowFrame else { return }
    overlays.show(
      focusedWindowFrame: lastFocusedWindowFrame,
      padding: settings.padding,
      strength: settings.strength
    )
  }

  @objc private func screensDidChange() {
    overlays.rebuild()
    refresh()
  }
}
