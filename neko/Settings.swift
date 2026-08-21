import Foundation
import Combine
import ServiceManagement

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

enum LoginItem {
    static var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    static var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    // macOS can accept the registration but park it behind user approval.
    static var requiresApproval: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .requiresApproval
    }

    static func openSettings() {
        guard #available(macOS 13.0, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        guard isEnabled != enabled else { return true }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    
    private let sizeKey = "nekoSize"
    private let speedKey = "nekoSpeed"
    private let hiddenKey = "nekoHidden"
    
    @Published var currentSize: NekoSize {
        didSet { UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey) }
    }
    
    @Published var currentSpeed: NekoSpeed {
        didSet { UserDefaults.standard.set(currentSpeed.rawValue, forKey: speedKey) }
    }

    @Published var isHidden: Bool {
        didSet { UserDefaults.standard.set(isHidden, forKey: hiddenKey) }
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

        let initialHidden = UserDefaults.standard.bool(forKey: hiddenKey)

        self.currentSize = initialSize
        self.currentSpeed = initialSpeed
        self.isHidden = initialHidden

        UserDefaults.standard.set(initialSize.rawValue, forKey: sizeKey)
        UserDefaults.standard.set(initialSpeed.rawValue, forKey: speedKey)
    }
}
