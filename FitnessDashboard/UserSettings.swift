import SwiftUI
import Combine

enum WeightUnit: String, CaseIterable {
    case imperial = "lbs"
    case metric = "kg"

    var displayName: String {
        switch self {
        case .imperial: return "Imperial (lbs)"
        case .metric: return "Metric (kg)"
        }
    }

    func convert(_ value: Double, to unit: WeightUnit) -> Double {
        if self == unit {
            return value
        }

        switch (self, unit) {
        case (.imperial, .metric):
            return value * 0.453592 // lbs to kg
        case (.metric, .imperial):
            return value * 2.20462 // kg to lbs
        default:
            return value
        }
    }
}

class UserSettings: ObservableObject {
    static let shared = UserSettings()

    @Published var weightUnit: WeightUnit {
        didSet {
            UserDefaults.standard.set(weightUnit.rawValue, forKey: "weightUnit")
        }
    }

    @Published var restTimerDuration: Int {
        didSet {
            UserDefaults.standard.set(restTimerDuration, forKey: "restTimerDuration")
        }
    }

    private init() {
        // Load from UserDefaults
        if let savedUnit = UserDefaults.standard.string(forKey: "weightUnit"),
           let unit = WeightUnit(rawValue: savedUnit) {
            self.weightUnit = unit
        } else {
            self.weightUnit = .imperial
        }

        self.restTimerDuration = UserDefaults.standard.integer(forKey: "restTimerDuration")
        if self.restTimerDuration == 0 {
            self.restTimerDuration = 120 // Default 2 minutes
        }
    }

    func formatWeight(_ weight: Double) -> String {
        return String(format: "%.1f %@", weight, weightUnit.rawValue)
    }

    func convertWeight(_ weight: Double, from fromUnit: WeightUnit) -> Double {
        return fromUnit.convert(weight, to: weightUnit)
    }
}
