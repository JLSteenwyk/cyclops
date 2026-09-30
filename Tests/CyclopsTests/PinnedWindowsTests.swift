import Testing

@testable import Cyclops

struct PinnedWindowsTests {
  @Test
  func togglingPinsAndThenUnpinsAWindow() {
    var pins = PinnedWindows<String>()

    let pinned = pins.toggle("editor")
    #expect(pinned)
    #expect(pins.windows == ["editor"])

    let unpinned = pins.toggle("editor")
    #expect(!unpinned)
    #expect(pins.windows.isEmpty)
  }

  @Test
  func keepsSeveralPinsInPinOrder() {
    var pins = PinnedWindows<String>()

    pins.toggle("editor")
    pins.toggle("terminal")
    pins.toggle("browser")
    pins.toggle("terminal")

    #expect(pins.windows == ["editor", "browser"])
  }

  @Test
  func dropsClosedWindows() {
    var pins = PinnedWindows<String>()
    pins.toggle("editor")
    pins.toggle("terminal")

    pins.remove(where: { $0 == "editor" })

    #expect(pins.windows == ["terminal"])
  }

  @Test
  func unpinsEverything() {
    var pins = PinnedWindows<String>()
    pins.toggle("editor")
    pins.toggle("terminal")

    pins.unpinAll()

    #expect(pins.windows.isEmpty)
  }
}
