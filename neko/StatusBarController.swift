import Cocoa
import Combine

final class StatusBarController {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.title = "🐱"
        }
        
        setupMenu()
        
        Settings.shared.$currentSize
            .sink { [weak self] _ in
                self?.updateMenuCheckmarks()
            }
            .store(in: &cancellables)
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        for size in NekoSize.allCases {
            let item = NSMenuItem(
                title: "\(size.displayName) (\(Int(size.rawValue))px)",
                action: #selector(sizeSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = Int(size.rawValue)
            item.state = Settings.shared.currentSize == size ? .on : .off
            menu.addItem(item)
        }
        
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
            if let size = NekoSize(rawValue: CGFloat(item.tag)) {
                item.state = Settings.shared.currentSize == size ? .on : .off
            }
        }
    }
    
    @objc private func sizeSelected(_ sender: NSMenuItem) {
        if let size = NekoSize(rawValue: CGFloat(sender.tag)) {
            Settings.shared.currentSize = size
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
