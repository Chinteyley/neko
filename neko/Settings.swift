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

enum NekoSign: Int, CaseIterable {
    case stillLeftAligned = 0
    case yelledAt = 1
    case fortySeven = 2

    var text: String {
        switch self {
        case .stillLeftAligned: "still left-aligned"
        case .yelledAt: "yelled at: 4"
        case .fortySeven: "$47"
        }
    }

    static func fromStoredValue(_ value: Any?) -> NekoSign? {
        guard let value else { return nil }

        if let number = value as? NSNumber {
            return NekoSign(rawValue: number.intValue)
        }
        if let number = value as? Int {
            return NekoSign(rawValue: number)
        }
        return nil
    }
}

enum NekoSignMetrics {
    static let bubbleWidth: CGFloat = 128
    static let bubbleHeight: CGFloat = 20
    static let stickHeight: CGFloat = 4

    static func windowSize(for size: NekoSize) -> CGSize {
        CGSize(
            width: max(size.rawValue, bubbleWidth),
            height: size.rawValue + stickHeight + bubbleHeight
        )
    }

    static func spriteRect(for size: NekoSize) -> CGRect {
        CGRect(x: 0, y: 0, width: size.rawValue, height: size.rawValue)
    }

    static func signRect(for size: NekoSize) -> CGRect {
        CGRect(
            x: 0,
            y: size.rawValue + stickHeight,
            width: bubbleWidth,
            height: bubbleHeight
        )
    }

    static func stickRect(for size: NekoSize) -> CGRect {
        let x = max(0, size.rawValue / 2 - 1)
        return CGRect(x: x, y: size.rawValue, width: 2, height: stickHeight)
    }

    static func contains(_ mouse: CGPoint, windowFrame: CGRect, size: NekoSize) -> Bool {
        guard windowFrame.contains(mouse) else { return false }
        let local = CGPoint(x: mouse.x - windowFrame.minX, y: mouse.y - windowFrame.minY)
        return spriteRect(for: size).contains(local)
            || signRect(for: size).contains(local)
            || stickRect(for: size).contains(local)
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
    private let signKey = "nekoSign"
    
    @Published var currentSize: NekoSize {
        didSet { UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey) }
    }
    
    @Published var currentSpeed: NekoSpeed {
        didSet { UserDefaults.standard.set(currentSpeed.rawValue, forKey: speedKey) }
    }

    @Published var isHidden: Bool {
        didSet { UserDefaults.standard.set(isHidden, forKey: hiddenKey) }
    }

    @Published var currentSign: NekoSign {
        didSet { UserDefaults.standard.set(currentSign.rawValue, forKey: signKey) }
    }

    func cycleSign() {
        let all = NekoSign.allCases
        guard let index = all.firstIndex(of: currentSign) else {
            currentSign = all[0]
            return
        }
        currentSign = all[(index + 1) % all.count]
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
        let initialSign = NekoSign.fromStoredValue(UserDefaults.standard.object(forKey: signKey)) ?? .stillLeftAligned

        self.currentSize = initialSize
        self.currentSpeed = initialSpeed
        self.isHidden = initialHidden
        self.currentSign = initialSign

        UserDefaults.standard.set(initialSize.rawValue, forKey: sizeKey)
        UserDefaults.standard.set(initialSpeed.rawValue, forKey: speedKey)
        UserDefaults.standard.set(initialSign.rawValue, forKey: signKey)
    }
}
