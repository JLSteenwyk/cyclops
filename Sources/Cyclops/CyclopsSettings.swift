import Foundation

enum BackdropStrength: String, CaseIterable {
  case gentle
  case balanced
  case deep

  var title: String {
    rawValue.capitalized
  }

  var dimOpacity: CGFloat {
    switch self {
    case .gentle: 0.12
    case .balanced: 0.26
    case .deep: 0.42
    }
  }
}

@MainActor
final class CyclopsSettings {
  private enum Key {
    static let strength = "backdropStrength"
    static let padding = "focusPadding"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var strength: BackdropStrength {
    get {
      guard
        let value = defaults.string(forKey: Key.strength),
        let strength = BackdropStrength(rawValue: value)
      else {
        return .balanced
      }
      return strength
    }
    set {
      defaults.set(newValue.rawValue, forKey: Key.strength)
    }
  }

  var padding: CGFloat {
    get {
      guard defaults.object(forKey: Key.padding) != nil else { return 10 }
      return CGFloat(defaults.double(forKey: Key.padding))
    }
    set {
      defaults.set(Double(newValue), forKey: Key.padding)
    }
  }
}
