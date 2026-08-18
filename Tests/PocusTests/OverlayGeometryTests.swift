import AppKit
import Testing

@testable import Pocus

struct OverlayGeometryTests {
  @Test
  func convertsAccessibilityCoordinatesToAppKitCoordinates() {
    let accessibilityRect = CGRect(x: 120, y: 80, width: 640, height: 480)

    let converted = CoordinateConverter.appKitRect(
      fromAccessibilityRect: accessibilityRect,
      primaryScreenMaxY: 900
    )

    #expect(converted == CGRect(x: 120, y: 340, width: 640, height: 480))
  }

  @Test
  func convertsCoordinatesOnDisplayBelowPrimaryScreen() {
    let accessibilityRect = CGRect(x: 0, y: 950, width: 500, height: 300)

    let converted = CoordinateConverter.appKitRect(
      fromAccessibilityRect: accessibilityRect,
      primaryScreenMaxY: 900
    )

    #expect(converted == CGRect(x: 0, y: -350, width: 500, height: 300))
  }

  @Test
  func expandsAndTranslatesFocusRectIntoScreenCoordinates() {
    let result = OverlayGeometry.localFocusRect(
      globalFocusRect: CGRect(x: 100, y: 150, width: 500, height: 300),
      screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
      padding: 10
    )

    #expect(result == CGRect(x: 90, y: 140, width: 520, height: 320))
  }

  @Test
  func clipsFocusRectAtSecondaryScreenBoundary() {
    let result = OverlayGeometry.localFocusRect(
      globalFocusRect: CGRect(x: 1300, y: 100, width: 400, height: 500),
      screenFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      padding: 10
    )

    #expect(result == CGRect(x: 0, y: 90, width: 270, height: 520))
  }

  @Test
  func returnsNilWhenFocusRectDoesNotTouchScreen() {
    let result = OverlayGeometry.localFocusRect(
      globalFocusRect: CGRect(x: 100, y: 100, width: 400, height: 300),
      screenFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      padding: 10
    )

    #expect(result == nil)
  }

  @Test @MainActor
  func constructsOverlayPanelWithoutReenteringSubclassInitializer() throws {
    _ = NSApplication.shared
    let screen = try #require(NSScreen.screens.first)

    let panel = FocusOverlayPanel(screen: screen)

    panel.hide()
  }
}
