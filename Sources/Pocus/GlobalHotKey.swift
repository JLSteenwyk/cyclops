import AppKit
import Carbon.HIToolbox

enum FocusShortcut {
  static let keyCode = UInt32(kVK_ANSI_P)
  static let carbonModifiers = UInt32(controlKey | optionKey | cmdKey)
  static let keyEquivalent = "p"
  static let menuModifierMask: NSEvent.ModifierFlags = [.control, .option, .command]

  @MainActor
  static func configure(menuItem: NSMenuItem) {
    menuItem.keyEquivalent = keyEquivalent
    menuItem.keyEquivalentModifierMask = menuModifierMask
  }
}

enum GlobalHotKeyError: LocalizedError {
  case eventHandler(OSStatus)
  case registration(OSStatus)

  var errorDescription: String? {
    switch self {
    case .eventHandler(let status):
      "Could not install the global hotkey event handler (OSStatus \(status))."
    case .registration(let status):
      "Could not register Control–Option–Command–P; another app may already use it "
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
  private static let identifier: UInt32 = 1
  private static let eventHandler: EventHandlerUPP = {
    _, _, userData in
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
      hotKey.performAction()
    }
    return noErr
  }

  private let action: Action
  private var eventHandlerReference: EventHandlerRef?
  private var hotKeyReference: EventHotKeyRef?

  init(action: @escaping Action) {
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
      id: Self.identifier
    )
    let registrationStatus = RegisterEventHotKey(
      FocusShortcut.keyCode,
      FocusShortcut.carbonModifiers,
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
      throw GlobalHotKeyError.registration(registrationStatus)
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
