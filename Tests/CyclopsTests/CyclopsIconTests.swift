import AppKit
import Testing

@testable import Cyclops

@Suite("Cyclops icon")
struct CyclopsIconTests {
  @Test @MainActor
  func createsAnAlwaysVisibleTemplateStatusIcon() throws {
    let image = CyclopsIcon.statusImage()

    #expect(image.size == NSSize(width: 18, height: 18))
    #expect(image.isTemplate)
    #expect(image.accessibilityDescription == "Cyclops")
    #expect(try #require(image.tiffRepresentation).isEmpty == false)
  }
}
