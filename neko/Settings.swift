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
    case hyper = 0.06
    
    var displayName: String {
        switch self {
        case .slow: "Slow"
        case .normal: "Normal"
        case .fast: "Fast"
        case .hyper: "Hyper"
        }
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    
    private let sizeKey = "nekoSize"
    private let speedKey = "nekoSpeed"
    private let idleAnimationsKey = "nekoIdleAnimations"
    private let enabledKey = "nekoEnabled"
    
    @Published var currentSize: NekoSize {
        didSet { UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey) }
    }
    
    @Published var currentSpeed: NekoSpeed {
        didSet { UserDefaults.standard.set(currentSpeed.rawValue, forKey: speedKey) }
    }
    
    @Published var idleAnimationsEnabled: Bool {
        didSet { UserDefaults.standard.set(idleAnimationsEnabled, forKey: idleAnimationsKey) }
    }

    @Published var nekoEnabled: Bool {
        didSet { UserDefaults.standard.set(nekoEnabled, forKey: enabledKey) }
    }

    private init() {
        let savedSizeObject = UserDefaults.standard.object(forKey: sizeKey)
        currentSize = NekoSize.fromStoredValue(savedSizeObject) ?? .medium
        UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey)
        
        let savedSpeed = UserDefaults.standard.double(forKey: speedKey)
        if savedSpeed > 0, let speed = NekoSpeed(rawValue: savedSpeed) {
            currentSpeed = speed
        } else {
            currentSpeed = .normal
        }
        
        if UserDefaults.standard.object(forKey: idleAnimationsKey) != nil {
            idleAnimationsEnabled = UserDefaults.standard.bool(forKey: idleAnimationsKey)
        } else {
            idleAnimationsEnabled = true
        }

        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            nekoEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        } else {
            nekoEnabled = true
        }
    }
}
