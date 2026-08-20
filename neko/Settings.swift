import Foundation
import Combine

enum NekoSize: CGFloat, CaseIterable {
    case small = 16
    case medium = 24
    case large = 32
    
    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }
    
    var scale: CGFloat {
        rawValue / 16
    }

    static func fromSavedValue(_ value: Double) -> NekoSize {
        let raw = CGFloat(value)
        if let size = NekoSize(rawValue: raw) {
            return size
        }
        return NekoSize.allCases.min(by: { abs($0.rawValue - raw) < abs($1.rawValue - raw) }) ?? .small
    }

    static func fromStoredValue(_ value: Any?) -> NekoSize? {
        guard let value else { return nil }

        if let number = value as? NSNumber {
            return fromSavedValue(number.doubleValue)
        }
        if let number = value as? Double {
            return fromSavedValue(number)
        }
        if let number = value as? CGFloat {
            return fromSavedValue(Double(number))
        }
        if let string = value as? String {
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let number = Double(normalized) {
                return fromSavedValue(number)
            }
            switch normalized {
            case "tiny", "small":
                return .small
            case "mid", "medium":
                return .medium
            case "big", "large", "huge":
                return .large
            default:
                return nil
            }
        }
        return nil
    }
}

enum NekoSpeed: Double, CaseIterable {
    case slow = 0.24
    case normal = 0.16
    case fast = 0.10
    
    var displayName: String {
        switch self {
        case .slow: "Slow"
        case .normal: "Normal"
        case .fast: "Fast"
        }
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    
    private let sizeKey = "nekoSize"
    private let speedKey = "nekoSpeed"
    
    @Published var currentSize: NekoSize {
        didSet { UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey) }
    }
    
    @Published var currentSpeed: NekoSpeed {
        didSet { UserDefaults.standard.set(currentSpeed.rawValue, forKey: speedKey) }
    }

    private init() {
        let savedSizeObject = UserDefaults.standard.object(forKey: sizeKey)
        let initialSize = NekoSize.fromStoredValue(savedSizeObject) ?? .medium

        let savedSpeed = UserDefaults.standard.double(forKey: speedKey)
        let initialSpeed: NekoSpeed
        if savedSpeed > 0, let exact = NekoSpeed(rawValue: savedSpeed) {
            initialSpeed = exact
        } else if savedSpeed > 0 {
            let nearest = NekoSpeed.allCases.min(by: { abs($0.rawValue - savedSpeed) < abs($1.rawValue - savedSpeed) })
            initialSpeed = nearest ?? .normal
        } else {
            initialSpeed = .normal
        }

        self.currentSize = initialSize
        self.currentSpeed = initialSpeed

        UserDefaults.standard.set(initialSize.rawValue, forKey: sizeKey)
        UserDefaults.standard.set(initialSpeed.rawValue, forKey: speedKey)
    }
}
