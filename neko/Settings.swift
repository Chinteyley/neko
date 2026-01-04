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
        case .tiny: return "Tiny"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .huge: return "Huge"
        }
    }
    
    var scale: CGFloat {
        rawValue / 16
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    
    private let sizeKey = "nekoSize"
    private var cancellables = Set<AnyCancellable>()
    
    @Published var currentSize: NekoSize {
        didSet {
            UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey)
        }
    }
    
    private init() {
        let savedValue = UserDefaults.standard.double(forKey: sizeKey)
        if savedValue > 0, let size = NekoSize(rawValue: CGFloat(savedValue)) {
            currentSize = size
        } else {
            currentSize = .small
        }
    }
}
