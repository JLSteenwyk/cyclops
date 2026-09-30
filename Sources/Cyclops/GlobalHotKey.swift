import AppKit
import Carbon.HIToolbox

struct GlobalShortcut: Sendable {
  let keyCode: UInt32
  let carbonModifiers: UInt32
  let keyEquivalent: String
  let menuModifierMask: NSEvent.ModifierFlags
  let identifier: UInt32
  let displayName: String

  static let pause = GlobalShortcut(
    keyCode: UInt32(kVK_ANSI_P),
    carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
    keyEquivalent: "p",
    menuModifierMask: [.control, .option, .command],
    identifier: 1,
    displayName: "Control–Option–Command–P"
  )

  static let pin = GlobalShortcut(
    keyCode: UInt32(kVK_ANSI_K),
    carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
    keyEquivalent: "k",
    menuModifierMask: [.control, .option, .command],
    identifier: 2,
    displayName: "Control–Option–Command–K"
  )

  @MainActor
  func configure(menuItem: NSMenuItem) {
    menuItem.keyEquivalent = keyEquivalent
    menuItem.keyEquivalentModifierMask = menuModifierMask
  }
}

enum GlobalHotKeyError: LocalizedError {
  case eventHandler(OSStatus)
  case registration(String, OSStatus)

  var errorDescription: String? {
    switch self {
    case .eventHandler(let status):
      "Could not install the global hotkey event handler (OSStatus \(status))."
    case .registration(let displayName, let status):
      "Could not register \(displayName); another app may already use it "
        + "(OSStatus \(status))."
    }
  }
}

struct ShortcutDeliveryDeduplicator {
  enum Source {
    case appKit
    case carbon
  }

  private var lastDelivery: (source: Source, time: TimeInterval)?
  private let duplicateWindow: TimeInterval

  init(duplicateWindow: TimeInterval = 0.25) {
    self.duplicateWindow = duplicateWindow
  }

  mutating func shouldPerform(source: Source, at time: TimeInterval) -> Bool {
    if let lastDelivery,
      lastDelivery.source != source,
      time - lastDelivery.time <= duplicateWindow
    {
      self.lastDelivery = nil
      return false
    }

    lastDelivery = (source, time)
    return true
  }
}

@MainActor
final class GlobalHotKey: @unchecked Sendable {
  typealias Action = @MainActor () -> Void

  private static let signature: OSType = 0x504F4353  // POCS
  private static let eventHandler: EventHandlerUPP = {
    _, event, userData in
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    guard let event else { return OSStatus(eventNotHandledErr) }
    var pressedID = EventHotKeyID()
    let status = GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &pressedID
    )
    // Every registered hotkey receives each press, so ignore the other shortcuts' presses.
    guard status == noErr, pressedID.id == hotKey.shortcut.identifier else {
      return OSStatus(eventNotHandledErr)
    }
    MainActor.assumeIsolated {
      hotKey.performAction()
    }
    return noErr
  }

  let shortcut: GlobalShortcut
  private let action: Action
  private var eventHandlerReference: EventHandlerRef?
  private var hotKeyReference: EventHotKeyRef?

  init(shortcut: GlobalShortcut, action: @escaping Action) {
    self.shortcut = shortcut
    self.action = action
  }

  func register() throws {
    guard hotKeyReference == nil else { return }

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    let handlerStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      Self.eventHandler,
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandlerReference
    )
    guard handlerStatus == noErr else {
      eventHandlerReference = nil
      throw GlobalHotKeyError.eventHandler(handlerStatus)
    }

    var reference: EventHotKeyRef?
    let hotKeyID = EventHotKeyID(
      signature: Self.signature,
      id: shortcut.identifier
    )
    let registrationStatus = RegisterEventHotKey(
      shortcut.keyCode,
      shortcut.carbonModifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &reference
    )
    guard registrationStatus == noErr, let reference else {
      if let eventHandlerReference {
        RemoveEventHandler(eventHandlerReference)
      }
      eventHandlerReference = nil
      throw GlobalHotKeyError.registration(shortcut.displayName, registrationStatus)
    }
    hotKeyReference = reference
  }

  func unregister() {
    if let hotKeyReference {
      UnregisterEventHotKey(hotKeyReference)
      self.hotKeyReference = nil
    }
    if let eventHandlerReference {
      RemoveEventHandler(eventHandlerReference)
      self.eventHandlerReference = nil
    }
  }

  func performAction() {
    action()
  }
}
