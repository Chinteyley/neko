import Cocoa
import Combine

final class StatusBarController {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    var onSpeedChange: (() -> Void)?
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.title = "🐱"
        }
        
        setupMenu()
        
        Settings.shared.$currentSize
            .sink { [weak self] _ in self?.updateMenuCheckmarks() }
            .store(in: &cancellables)
        
        Settings.shared.$currentSpeed
            .sink { [weak self] _ in self?.updateMenuCheckmarks() }
            .store(in: &cancellables)
        
        Settings.shared.$idleAnimationsEnabled
            .sink { [weak self] _ in self?.updateMenuCheckmarks() }
            .store(in: &cancellables)
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let sizeHeader = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeHeader.isEnabled = false
        menu.addItem(sizeHeader)
        
        for size in NekoSize.allCases {
            let item = NSMenuItem(
                title: "  \(size.displayName) (\(Int(size.rawValue))px)",
                action: #selector(sizeSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = Int(size.rawValue)
            item.state = Settings.shared.currentSize == size ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let speedHeader = NSMenuItem(title: "Speed", action: nil, keyEquivalent: "")
        speedHeader.isEnabled = false
        menu.addItem(speedHeader)
        
        for speed in NekoSpeed.allCases {
            let item = NSMenuItem(
                title: "  \(speed.displayName)",
                action: #selector(speedSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = speed.rawValue
            item.state = Settings.shared.currentSpeed == speed ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let idleItem = NSMenuItem(
            title: "Idle Animations",
            action: #selector(toggleIdleAnimations(_:)),
            keyEquivalent: ""
        )
        idleItem.target = self
        idleItem.state = Settings.shared.idleAnimationsEnabled ? .on : .off
        menu.addItem(idleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit Neko",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func updateMenuCheckmarks() {
        guard let menu = statusItem.menu else { return }
        
        for item in menu.items {
            if let size = NekoSize(rawValue: CGFloat(item.tag)), item.tag > 0 {
                item.state = Settings.shared.currentSize == size ? .on : .off
            }
            
            if let speedValue = item.representedObject as? Double,
               let speed = NekoSpeed(rawValue: speedValue) {
                item.state = Settings.shared.currentSpeed == speed ? .on : .off
            }
            
            if item.action == #selector(toggleIdleAnimations(_:)) {
                item.state = Settings.shared.idleAnimationsEnabled ? .on : .off
            }
        }
    }
    
    @objc private func sizeSelected(_ sender: NSMenuItem) {
        if let size = NekoSize(rawValue: CGFloat(sender.tag)) {
            Settings.shared.currentSize = size
        }
    }
    
    @objc private func speedSelected(_ sender: NSMenuItem) {
        if let speedValue = sender.representedObject as? Double,
           let speed = NekoSpeed(rawValue: speedValue) {
            Settings.shared.currentSpeed = speed
            onSpeedChange?()
        }
    }
    
    @objc private func toggleIdleAnimations(_ sender: NSMenuItem) {
        Settings.shared.idleAnimationsEnabled.toggle()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
