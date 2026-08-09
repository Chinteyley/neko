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

enum NekoFollowDistance: String, CaseIterable {
    case close
    case comfortable
    case far

    var displayName: String {
        switch self {
        case .close: "Close"
        case .comfortable: "Comfortable"
        case .far: "Far"
        }
    }

    var stopMultiplier: CGFloat {
        switch self {
        case .close: 1
        case .comfortable: 3
        case .far: 6
        }
    }

    var resumeMultiplier: CGFloat {
        stopMultiplier + 0.5
    }

    static func fromStoredValue(_ value: String?) -> NekoFollowDistance {
        NekoFollowDistance(rawValue: value ?? "") ?? .close
    }
}

enum NekoTheme: String, CaseIterable {
    case classic
    case ginger
    case blueGray

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .ginger: "Ginger"
        case .blueGray: "Blue/Gray"
        }
    }

    static func fromStoredValue(_ value: String?) -> NekoTheme {
        NekoTheme(rawValue: value ?? "") ?? .classic
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    
    private let sizeKey = "nekoSize"
    private let speedKey = "nekoSpeed"
    private let enabledKey = "nekoEnabled"
    private let followDistanceKey = "nekoFollowDistance"
    private let themeKey = "nekoTheme"
    
    @Published var currentSize: NekoSize {
        didSet { UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey) }
    }
    
    @Published var currentSpeed: NekoSpeed {
        didSet { UserDefaults.standard.set(currentSpeed.rawValue, forKey: speedKey) }
    }
    

    @Published var currentFollowDistance: NekoFollowDistance {
        didSet { UserDefaults.standard.set(currentFollowDistance.rawValue, forKey: followDistanceKey) }
    }

    @Published var currentTheme: NekoTheme {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey) }
    }
    var idleAnimationsEnabled: Bool { true }

    @Published var nekoEnabled: Bool {
        didSet { UserDefaults.standard.set(nekoEnabled, forKey: enabledKey) }
    }

    private init() {
        // Determine initial size without triggering didSet
        let savedSizeObject = UserDefaults.standard.object(forKey: sizeKey)
        let initialSize = NekoSize.fromStoredValue(savedSizeObject) ?? .medium

        // Determine initial speed (map any unknown/legacy value to nearest case)
        let savedSpeed = UserDefaults.standard.double(forKey: speedKey)
        let initialSpeed: NekoSpeed
        if savedSpeed > 0, let exact = NekoSpeed(rawValue: savedSpeed) {
            initialSpeed = exact
        } else if savedSpeed > 0 {
            // Map to nearest available speed
            let nearest = NekoSpeed.allCases.min(by: { abs($0.rawValue - savedSpeed) < abs($1.rawValue - savedSpeed) })
            initialSpeed = nearest ?? .normal
        } else {
            initialSpeed = .normal
        }


        let initialFollowDistance = NekoFollowDistance.fromStoredValue(
            UserDefaults.standard.string(forKey: followDistanceKey)
        )
        let initialTheme = NekoTheme.fromStoredValue(
            UserDefaults.standard.string(forKey: themeKey)
        )
        // Determine initial enabled flag
        let initialNekoEnabled: Bool
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            initialNekoEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        } else {
            initialNekoEnabled = true
        }

        // Now assign to stored properties once; didSet observers won't run during init
        self.currentSize = initialSize
        self.currentSpeed = initialSpeed
        self.currentFollowDistance = initialFollowDistance
        self.currentTheme = initialTheme
        self.nekoEnabled = initialNekoEnabled

        // Persist defaults explicitly after properties are initialized to avoid 'self' before init issues
        UserDefaults.standard.set(initialSize.rawValue, forKey: sizeKey)
        UserDefaults.standard.set(initialSpeed.rawValue, forKey: speedKey)
        UserDefaults.standard.set(initialFollowDistance.rawValue, forKey: followDistanceKey)
        UserDefaults.standard.set(initialTheme.rawValue, forKey: themeKey)
        UserDefaults.standard.set(initialNekoEnabled, forKey: enabledKey)
    }
}
