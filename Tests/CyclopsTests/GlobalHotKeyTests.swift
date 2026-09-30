import AppKit
import Carbon.HIToolbox
import Testing

@testable import Cyclops

struct GlobalHotKeyTests {
  @Test @MainActor
  func dispatchesTheRegisteredActionWithoutSynthesizingKeyboardInput() {
    var invocationCount = 0
    let hotKey = GlobalHotKey(shortcut: .pause) {
      invocationCount += 1
    }

    hotKey.performAction()

    #expect(invocationCount == 1)
  }

  @Test @MainActor
  func configuresTheMenuEquivalentForTheGlobalShortcut() {
    let menuItem = NSMenuItem(title: "Pause Focus", action: nil, keyEquivalent: "")

    GlobalShortcut.pause.configure(menuItem: menuItem)

    #expect(menuItem.keyEquivalent == "p")
    #expect(menuItem.keyEquivalentModifierMask == [.control, .option, .command])
  }

  @Test @MainActor
  func reportsAConflictWithoutCrashingWhenTheShortcutIsAlreadyRegistered() throws {
    let first = GlobalHotKey(shortcut: .pause) {}
    let conflicting = GlobalHotKey(shortcut: .pause) {}
    try first.register()
    defer {
      conflicting.unregister()
      first.unregister()
    }

    #expect(throws: GlobalHotKeyError.self) {
      try conflicting.register()
    }
  }

  @Test @MainActor
  func registersThePauseAndPinShortcutsSideBySide() throws {
    let pause = GlobalHotKey(shortcut: .pause) {}
    let pin = GlobalHotKey(shortcut: .pin) {}
    defer {
      pin.unregister()
      pause.unregister()
    }

    try pause.register()
    try pin.register()
  }

  @Test @MainActor
  func deliversEachPressOnlyToItsOwnShortcut() throws {
    var pauseCount = 0
    var pinCount = 0
    let pause = GlobalHotKey(shortcut: .pause) { pauseCount += 1 }
    let pin = GlobalHotKey(shortcut: .pin) { pinCount += 1 }
    try pause.register()
    try pin.register()
    defer {
      pin.unregister()
      pause.unregister()
    }

    try sendHotKeyPress(identifier: GlobalShortcut.pause.identifier)
    #expect(pauseCount == 1)
    #expect(pinCount == 0)

    try sendHotKeyPress(identifier: GlobalShortcut.pin.identifier)
    #expect(pauseCount == 1)
    #expect(pinCount == 1)
  }

  @MainActor
  private func sendHotKeyPress(identifier: UInt32) throws {
    var event: EventRef?
    let createStatus = CreateEvent(
      nil,
      OSType(kEventClassKeyboard),
      UInt32(kEventHotKeyPressed),
      0,
      EventAttributes(kEventAttributeNone),
      &event
    )
    let hotKeyEvent = try #require(createStatus == noErr ? event : nil)
    defer { ReleaseEvent(hotKeyEvent) }

    var hotKeyID = EventHotKeyID(signature: 0x504F_4353, id: identifier)
    SetEventParameter(
      hotKeyEvent,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      MemoryLayout<EventHotKeyID>.size,
      &hotKeyID
    )
    SendEventToEventTarget(hotKeyEvent, GetApplicationEventTarget())
  }

  @Test @MainActor
  func reportsAConflictForTheSecondPinRegistration() throws {
    let first = GlobalHotKey(shortcut: .pin) {}
    let conflicting = GlobalHotKey(shortcut: .pin) {}
    try first.register()
    defer {
      conflicting.unregister()
      first.unregister()
    }

    #expect(throws: GlobalHotKeyError.self) {
      try conflicting.register()
    }
  }

  @Test
  func coalescesAppKitAndCarbonDeliveriesForTheSameKeypress() {
    var appKitFirst = ShortcutDeliveryDeduplicator()
    let firstAppKitDelivery = appKitFirst.shouldPerform(source: .appKit, at: 1)
    let duplicateCarbonDelivery = appKitFirst.shouldPerform(source: .carbon, at: 1.01)
    #expect(firstAppKitDelivery)
    #expect(!duplicateCarbonDelivery)

    var carbonFirst = ShortcutDeliveryDeduplicator()
    let firstCarbonDelivery = carbonFirst.shouldPerform(source: .carbon, at: 2)
    let duplicateAppKitDelivery = carbonFirst.shouldPerform(source: .appKit, at: 2.01)
    #expect(firstCarbonDelivery)
    #expect(!duplicateAppKitDelivery)
  }

  @Test
  func preservesDistinctShortcutKeypresses() {
    var deduplicator = ShortcutDeliveryDeduplicator()

    let firstDelivery = deduplicator.shouldPerform(source: .carbon, at: 1)
    let secondDelivery = deduplicator.shouldPerform(source: .carbon, at: 1.05)
    let laterDelivery = deduplicator.shouldPerform(source: .appKit, at: 2)
    #expect(firstDelivery)
    #expect(secondDelivery)
    #expect(laterDelivery)
  }

  @Test
  func usesTheDocumentedCarbonShortcut() {
    #expect(GlobalShortcut.pause.keyCode == UInt32(kVK_ANSI_P))
    #expect(GlobalShortcut.pause.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
  }

  @Test
  func usesControlOptionCommandKToPin() {
    #expect(GlobalShortcut.pin.keyCode == UInt32(kVK_ANSI_K))
    #expect(GlobalShortcut.pin.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
    #expect(GlobalShortcut.pin.keyEquivalent == "k")
  }
}
