import AppKit
import Carbon.HIToolbox
import Testing

@testable import Cyclops

struct GlobalHotKeyTests {
  @Test @MainActor
  func dispatchesTheRegisteredActionWithoutSynthesizingKeyboardInput() {
    var invocationCount = 0
    let hotKey = GlobalHotKey {
      invocationCount += 1
    }

    hotKey.performAction()

    #expect(invocationCount == 1)
  }

  @Test @MainActor
  func configuresTheMenuEquivalentForTheGlobalShortcut() {
    let menuItem = NSMenuItem(title: "Pause Focus", action: nil, keyEquivalent: "")

    FocusShortcut.configure(menuItem: menuItem)

    #expect(menuItem.keyEquivalent == "p")
    #expect(menuItem.keyEquivalentModifierMask == [.control, .option, .command])
  }

  @Test @MainActor
  func reportsAConflictWithoutCrashingWhenTheShortcutIsAlreadyRegistered() throws {
    let first = GlobalHotKey {}
    let conflicting = GlobalHotKey {}
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
    #expect(FocusShortcut.keyCode == UInt32(kVK_ANSI_P))
    #expect(FocusShortcut.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
  }
}
