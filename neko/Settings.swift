import Foundation
import Combine

enum NekoSize: CGFloat, CaseIterable {
    case tiny = 16
    case small = 32
    case medium = 48
    case large = 64
    case huge = 96
    
    var displayName: String {
        switch self {
        case .tiny: "Tiny"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .huge: "Huge"
        }
    }
    
    var scale: CGFloat {
        rawValue / 16
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
    
    @Published var currentSize: NekoSize {
        didSet { UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey) }
    }
    
    @Published var currentSpeed: NekoSpeed {
        didSet { UserDefaults.standard.set(currentSpeed.rawValue, forKey: speedKey) }
    }
    
    @Published var idleAnimationsEnabled: Bool {
        didSet { UserDefaults.standard.set(idleAnimationsEnabled, forKey: idleAnimationsKey) }
    }
    
    private init() {
        let savedSize = UserDefaults.standard.double(forKey: sizeKey)
        if savedSize > 0, let size = NekoSize(rawValue: CGFloat(savedSize)) {
            currentSize = size
        } else {
            currentSize = .small
        }
        
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
    }
}
