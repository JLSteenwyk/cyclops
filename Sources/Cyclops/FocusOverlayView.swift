import AppKit
import QuartzCore

@MainActor
final class FocusOverlayView: NSView {
  private let maskedContainer = NSView()
  private let blurView = NSVisualEffectView()
  private let dimView = NSView()
  private let maskLayer = CAShapeLayer()
  private let focusRingLayer = CAShapeLayer()

  private var focusRects: [CGRect] = []
  private var dimOpacity: CGFloat = BackdropStrength.balanced.dimOpacity

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    wantsLayer = true
    layer?.masksToBounds = true

    maskedContainer.wantsLayer = true
    maskedContainer.layer?.mask = maskLayer
    addSubview(maskedContainer)

    blurView.blendingMode = .behindWindow
    blurView.material = .hudWindow
    blurView.state = .active
    blurView.isEmphasized = true
    maskedContainer.addSubview(blurView)

    dimView.wantsLayer = true
    maskedContainer.addSubview(dimView)

    focusRingLayer.fillColor = NSColor.clear.cgColor
    focusRingLayer.strokeColor = NSColor.white.withAlphaComponent(0.38).cgColor
    focusRingLayer.lineWidth = 1
    layer?.addSublayer(focusRingLayer)

    updateLayers()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    maskedContainer.frame = bounds
    blurView.frame = bounds
    dimView.frame = bounds
    updateMask(animated: false)
  }

  func update(focusRects: [CGRect], strength: BackdropStrength, animated: Bool) {
    self.focusRects = focusRects
    dimOpacity = strength.dimOpacity
    updateLayers()
    updateMask(animated: animated)
  }

  private func updateLayers() {
    dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(dimOpacity).cgColor
  }

  private func updateMask(animated: Bool) {
    let maskPath = OverlayGeometry.maskPath(bounds: bounds, focusRects: focusRects)

    let oldPath = maskLayer.presentation()?.path ?? maskLayer.path
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    maskLayer.frame = bounds
    maskLayer.fillRule = .evenOdd
    maskLayer.fillColor = NSColor.white.cgColor
    maskLayer.path = maskPath
    focusRingLayer.frame = bounds
    focusRingLayer.path = OverlayGeometry.focusOutline(focusRects: focusRects)
    CATransaction.commit()

    guard animated, let oldPath else { return }
    let animation = CABasicAnimation(keyPath: "path")
    animation.fromValue = oldPath
    animation.toValue = maskPath
    animation.duration = 0.12
    animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
    maskLayer.add(animation, forKey: "focusTransition")
  }
}
