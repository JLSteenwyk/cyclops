import AppKit

@MainActor
final class FocusController: NSObject {
  private let accessibility: AccessibilityService
  private let settings: CyclopsSettings
  private let overlays = OverlayManager()
  private var refreshTimer: Timer?
  private var lastFocusedWindow: FocusedWindow?
  private var pins = PinnedWindows<TrackedWindow>()

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
    refreshUsingLastFrames()
    onStateChange?()
  }

  func setPadding(_ padding: CGFloat) {
    settings.padding = padding
    refreshUsingLastFrames()
    onStateChange?()
  }

  /// Pins the selected window, or unpins it if it is already pinned.
  func togglePinFocusedWindow() {
    guard let lastFocusedWindow else { return }
    pins.toggle(lastFocusedWindow.window)
    refreshUsingLastFrames()
    onStateChange?()
  }

  func unpinAll() {
    pins.unpinAll()
    refreshUsingLastFrames()
    onStateChange?()
  }

  var strength: BackdropStrength { settings.strength }
  var padding: CGFloat { settings.padding }
  var pinnedCount: Int { pins.count }
  var isFocusedWindowPinned: Bool {
    guard let lastFocusedWindow else { return false }
    return pins.windows.contains(lastFocusedWindow.window)
  }

  @objc private func refresh() {
    guard !isPaused, accessibility.isTrusted else {
      overlays.hide()
      return
    }

    switch accessibility.focusedWindow(excludingPID: ProcessInfo.processInfo.processIdentifier) {
    case .window(let focusedWindow):
      lastFocusedWindow = focusedWindow
      show([focusedWindow.frame] + visiblePinnedFrames())
    case .cyclopsIsFrontmost:
      // Keep the previous focus while Cyclops' own menu is open.
      refreshUsingLastFrames()
    case .noWindow:
      lastFocusedWindow = nil
      show(visiblePinnedFrames())
    }
  }

  private func visiblePinnedFrames() -> [CGRect] {
    guard !pins.isEmpty else { return [] }

    let onScreenWindows = OnScreenWindow.current()
    var frames: [CGRect] = []
    var closedWindows: [TrackedWindow] = []
    // The selected window is already clear, even when it is also pinned.
    for window in pins.windows where window != lastFocusedWindow?.window {
      switch accessibility.state(of: window, onScreenWindows: onScreenWindows) {
      case .visible(let frame):
        frames.append(frame)
      case .hidden:
        break
      case .closed:
        closedWindows.append(window)
      }
    }

    if !closedWindows.isEmpty {
      pins.remove(where: closedWindows.contains)
      onStateChange?()
    }
    return frames
  }

  private func show(_ focusRects: [CGRect]) {
    guard !focusRects.isEmpty else {
      overlays.hide()
      return
    }
    overlays.show(
      focusRects: focusRects,
      padding: settings.padding,
      strength: settings.strength
    )
  }

  private func refreshUsingLastFrames() {
    guard !isPaused else { return }
    show((lastFocusedWindow.map { [$0.frame] } ?? []) + visiblePinnedFrames())
  }

  @objc private func screensDidChange() {
    overlays.rebuild()
    refresh()
  }
}
