import AppKit
import Testing

@testable import Cyclops

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

  @Test
  func clipsEachFocusRectAndDropsThoseOffScreen() {
    let result = OverlayGeometry.localFocusRects(
      globalFocusRects: [
        CGRect(x: 100, y: 150, width: 500, height: 300),
        CGRect(x: 1300, y: 100, width: 400, height: 500),
        CGRect(x: 4000, y: 100, width: 400, height: 300),
      ],
      screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
      padding: 10
    )

    #expect(
      result == [
        CGRect(x: 90, y: 140, width: 520, height: 320),
        CGRect(x: 1290, y: 90, width: 150, height: 520),
      ]
    )
  }

  @Test
  func maskLeavesOverlappingFocusRectsClear() {
    let path = OverlayGeometry.maskPath(
      bounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
      focusRects: [
        CGRect(x: 100, y: 100, width: 300, height: 300),
        CGRect(x: 300, y: 300, width: 300, height: 300),
      ]
    )

    // The mask is filled where the blur shows, so focus areas must be unfilled.
    #expect(path.contains(CGPoint(x: 50, y: 50), using: .evenOdd))
    #expect(!path.contains(CGPoint(x: 150, y: 150), using: .evenOdd))
    #expect(!path.contains(CGPoint(x: 550, y: 550), using: .evenOdd))
    #expect(!path.contains(CGPoint(x: 350, y: 350), using: .evenOdd))
    #expect(path.contains(CGPoint(x: 550, y: 150), using: .evenOdd))
  }

  @Test
  func focusOutlineIsNilWithoutFocusRects() {
    #expect(OverlayGeometry.focusOutline(focusRects: []) == nil)
  }

  @Test
  func animatesOnlyWhenASingleFocusRectMoves() {
    let a = CGRect(x: 0, y: 0, width: 10, height: 10)
    let b = CGRect(x: 5, y: 5, width: 10, height: 10)

    #expect(OverlayGeometry.shouldAnimate(from: [a], to: [b]))
    #expect(!OverlayGeometry.shouldAnimate(from: [a], to: [a]))
    #expect(!OverlayGeometry.shouldAnimate(from: [], to: [b]))
    #expect(!OverlayGeometry.shouldAnimate(from: [a], to: [a, b]))
    #expect(!OverlayGeometry.shouldAnimate(from: [a, b], to: [b, a]))
  }

  @Test @MainActor
  func constructsOverlayPanelWithoutReenteringSubclassInitializer() throws {
    _ = NSApplication.shared
    let screen = try #require(NSScreen.screens.first)

    let panel = FocusOverlayPanel(screen: screen)

    panel.hide()
  }
}
