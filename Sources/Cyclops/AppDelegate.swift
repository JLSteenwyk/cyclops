import AppKit
@preconcurrency import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate,
  @MainActor SPUStandardUserDriverDelegate
{
  private let accessibility = AccessibilityService()
  private let settings = CyclopsSettings()
  private lazy var focusController = FocusController(
    accessibility: accessibility,
    settings: settings
  )
  private lazy var updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: self
  )
  private lazy var focusHotKey = GlobalHotKey(shortcut: .pause) { [weak self] in
    self?.performShortcutToggle(source: .carbon)
  }
  private lazy var pinHotKey = GlobalHotKey(shortcut: .pin) { [weak self] in
    self?.performPinToggle(source: .carbon)
  }
  private var focusHotKeyErrorDescription: String?
  private var pinHotKeyErrorDescription: String?
  private var shortcutDeduplicator = ShortcutDeliveryDeduplicator()
  private var pinShortcutDeduplicator = ShortcutDeliveryDeduplicator()
  private var statusItem: NSStatusItem!

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = CyclopsIcon.statusImage()
    statusItem.button?.appearsDisabled = false
    statusItem.button?.toolTip = "Cyclops — focus on the selected window"

    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu

    do {
      try focusHotKey.register()
    } catch {
      focusHotKeyErrorDescription = error.localizedDescription
      NSLog("Cyclops global shortcut unavailable: %@", error.localizedDescription)
    }
    do {
      try pinHotKey.register()
    } catch {
      pinHotKeyErrorDescription = error.localizedDescription
      NSLog("Cyclops pin shortcut unavailable: %@", error.localizedDescription)
    }
    rebuildMenu()

    focusController.start()

    if !accessibility.isTrusted {
      accessibility.requestPermission()
    }
  }

  func menuWillOpen(_ menu: NSMenu) {
    rebuildMenu()
  }

  func applicationWillTerminate(_ notification: Notification) {
    focusHotKey.unregister()
    pinHotKey.unregister()
  }

  var supportsGentleScheduledUpdateReminders: Bool {
    true
  }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool,
    forUpdate update: SUAppcastItem,
    state: SPUUserUpdateState
  ) {
    guard handleShowingUpdate else { return }
    NSApp.setActivationPolicy(.regular)
    if !state.userInitiated {
      NSApp.dockTile.badgeLabel = "1"
    }
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    NSApp.dockTile.badgeLabel = nil
  }

  func standardUserDriverWillFinishUpdateSession() {
    NSApp.dockTile.badgeLabel = nil
    NSApp.setActivationPolicy(.accessory)
  }

  private func rebuildMenu() {
    guard let menu = statusItem?.menu else { return }
    menu.removeAllItems()

    let title = NSMenuItem(title: "Cyclops", action: nil, keyEquivalent: "")
    title.isEnabled = false
    menu.addItem(title)

    if accessibility.isTrusted {
      let toggleTitle = focusController.isPaused ? "Resume Focus" : "Pause Focus"
      let toggleItem = NSMenuItem(
        title: toggleTitle,
        action: #selector(toggleFocus),
        keyEquivalent: ""
      )
      toggleItem.target = self
      GlobalShortcut.pause.configure(menuItem: toggleItem)
      toggleItem.toolTip = focusHotKeyErrorDescription
      menu.addItem(toggleItem)

      let explanation = NSMenuItem(
        title: "Following the selected window",
        action: nil,
        keyEquivalent: ""
      )
      explanation.isEnabled = false
      menu.addItem(explanation)

      menu.addItem(.separator())
      let pinTitle =
        focusController.isFocusedWindowPinned
        ? "Unpin Selected Window" : "Pin Selected Window"
      let pinItem = NSMenuItem(
        title: pinTitle,
        action: #selector(togglePin),
        keyEquivalent: ""
      )
      pinItem.target = self
      GlobalShortcut.pin.configure(menuItem: pinItem)
      pinItem.toolTip = pinHotKeyErrorDescription
      menu.addItem(pinItem)

      let pinnedCount = focusController.pinnedCount
      if pinnedCount > 0 {
        let pinnedSummary = NSMenuItem(
          title: pinnedCount == 1 ? "1 window pinned" : "\(pinnedCount) windows pinned",
          action: nil,
          keyEquivalent: ""
        )
        pinnedSummary.isEnabled = false
        menu.addItem(pinnedSummary)
      }

      let unpinAllItem = NSMenuItem(
        title: "Unpin All Windows",
        action: pinnedCount > 0 ? #selector(unpinAll) : nil,
        keyEquivalent: ""
      )
      unpinAllItem.target = self
      menu.addItem(unpinAllItem)
    } else {
      let warning = NSMenuItem(
        title: "Accessibility access is required",
        action: nil,
        keyEquivalent: ""
      )
      warning.isEnabled = false
      menu.addItem(warning)

      let permissionItem = NSMenuItem(
        title: "Grant Accessibility Access…",
        action: #selector(requestAccessibilityPermission),
        keyEquivalent: ""
      )
      permissionItem.target = self
      menu.addItem(permissionItem)
    }

    if let focusHotKeyErrorDescription {
      let shortcutWarning = NSMenuItem(
        title: "Global shortcut unavailable",
        action: nil,
        keyEquivalent: ""
      )
      shortcutWarning.isEnabled = false
      shortcutWarning.toolTip = focusHotKeyErrorDescription
      menu.addItem(shortcutWarning)
    }

    if let pinHotKeyErrorDescription {
      let shortcutWarning = NSMenuItem(
        title: "Pin shortcut unavailable",
        action: nil,
        keyEquivalent: ""
      )
      shortcutWarning.isEnabled = false
      shortcutWarning.toolTip = pinHotKeyErrorDescription
      menu.addItem(shortcutWarning)
    }

    menu.addItem(.separator())
    menu.addItem(strengthMenuItem())
    menu.addItem(paddingMenuItem())
    menu.addItem(.separator())

    let updateItem = NSMenuItem(
      title: "Check for Updates…",
      action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
      keyEquivalent: ""
    )
    updateItem.target = updaterController
    updateItem.isEnabled = updaterController.updater.canCheckForUpdates
    menu.addItem(updateItem)

    let settingsItem = NSMenuItem(
      title: "Open Accessibility Settings…",
      action: #selector(openAccessibilitySettings),
      keyEquivalent: ""
    )
    settingsItem.target = self
    menu.addItem(settingsItem)

    let quitItem = NSMenuItem(
      title: "Quit Cyclops",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    menu.addItem(quitItem)
  }

  private func strengthMenuItem() -> NSMenuItem {
    let parent = NSMenuItem(title: "Backdrop", action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: "Backdrop")

    for strength in BackdropStrength.allCases {
      let item = NSMenuItem(
        title: strength.title,
        action: #selector(selectStrength(_:)),
        keyEquivalent: ""
      )
      item.target = self
      item.representedObject = strength.rawValue
      item.state = focusController.strength == strength ? .on : .off
      submenu.addItem(item)
    }

    parent.submenu = submenu
    return parent
  }

  private func paddingMenuItem() -> NSMenuItem {
    let parent = NSMenuItem(title: "Focus Padding", action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: "Focus Padding")

    for padding in [CGFloat(0), 6, 10, 18] {
      let item = NSMenuItem(
        title: padding == 0 ? "None" : "\(Int(padding)) pt",
        action: #selector(selectPadding(_:)),
        keyEquivalent: ""
      )
      item.target = self
      item.representedObject = NSNumber(value: Double(padding))
      item.state = focusController.padding == padding ? .on : .off
      submenu.addItem(item)
    }

    parent.submenu = submenu
    return parent
  }

  @objc private func toggleFocus() {
    performShortcutToggle(source: .appKit)
  }

  private func performShortcutToggle(source: ShortcutDeliveryDeduplicator.Source) {
    let now = ProcessInfo.processInfo.systemUptime
    guard shortcutDeduplicator.shouldPerform(source: source, at: now) else { return }
    focusController.togglePaused()
  }

  @objc private func togglePin() {
    performPinToggle(source: .appKit)
  }

  private func performPinToggle(source: ShortcutDeliveryDeduplicator.Source) {
    let now = ProcessInfo.processInfo.systemUptime
    guard pinShortcutDeduplicator.shouldPerform(source: source, at: now) else { return }
    focusController.togglePinFocusedWindow()
  }

  @objc private func unpinAll() {
    focusController.unpinAll()
  }

  @objc private func requestAccessibilityPermission() {
    accessibility.requestPermission()
  }

  @objc private func openAccessibilitySettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      )
    else { return }
    NSWorkspace.shared.open(url)
  }

  @objc private func selectStrength(_ sender: NSMenuItem) {
    guard
      let rawValue = sender.representedObject as? String,
      let strength = BackdropStrength(rawValue: rawValue)
    else { return }
    focusController.setStrength(strength)
  }

  @objc private func selectPadding(_ sender: NSMenuItem) {
    guard let value = sender.representedObject as? NSNumber else { return }
    focusController.setPadding(CGFloat(value.doubleValue))
  }
}
