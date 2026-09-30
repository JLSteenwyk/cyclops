import CoreGraphics
import Testing

@testable import Cyclops

struct OnScreenWindowTests {
  private func info(
    pid: Int,
    bounds: CGRect,
    layer: Int = 0
  ) -> [String: Any] {
    [
      kCGWindowOwnerPID as String: pid,
      kCGWindowLayer as String: layer,
      kCGWindowBounds as String: bounds.dictionaryRepresentation,
    ]
  }

  @Test
  func parsesRegularWindowsAndSkipsOtherLayers() {
    let windows = OnScreenWindow.parse([
      info(pid: 42, bounds: CGRect(x: 10, y: 20, width: 300, height: 200)),
      info(pid: 7, bounds: CGRect(x: 0, y: 0, width: 1440, height: 24), layer: 25),
      [kCGWindowOwnerPID as String: 9],
    ])

    #expect(windows == [OnScreenWindow(pid: 42, frame: CGRect(x: 10, y: 20, width: 300, height: 200))])
  }

  @Test
  func matchesAWindowWithTheSameOwnerAndFrame() {
    let windows = [OnScreenWindow(pid: 42, frame: CGRect(x: 10, y: 20, width: 300, height: 200))]

    #expect(
      OnScreenWindow.isVisible(
        pid: 42,
        accessibilityFrame: CGRect(x: 10.4, y: 19.6, width: 300, height: 200.5),
        among: windows
      )
    )
  }

  @Test
  func rejectsWindowsFromOtherAppsOrWithOtherFrames() {
    let windows = [OnScreenWindow(pid: 42, frame: CGRect(x: 10, y: 20, width: 300, height: 200))]

    #expect(
      !OnScreenWindow.isVisible(
        pid: 43,
        accessibilityFrame: CGRect(x: 10, y: 20, width: 300, height: 200),
        among: windows
      )
    )
    #expect(
      !OnScreenWindow.isVisible(
        pid: 42,
        accessibilityFrame: CGRect(x: 60, y: 20, width: 300, height: 200),
        among: windows
      )
    )
  }
}
