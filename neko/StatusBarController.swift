import Cocoa

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem
    private var hideItem: NSMenuItem?
    private var loginItem: NSMenuItem?
    var onSpeedChange: (() -> Void)?
    
    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        
        if let button = statusItem.button {
            button.image = Self.menuBarIcon()
            button.imagePosition = .imageOnly
            button.title = ""
        }
        
        setupMenu()
    }

    // Sized to the sprite's own pixel grid so the art never lands on a fractional scale.
    private static func menuBarIcon() -> NSImage? {
        guard let asset = NSImage(named: "MenuBarIcon"),
              let icon = asset.copy() as? NSImage else { return nil }
        icon.size = NSSize(width: 16, height: 16)
        icon.isTemplate = true
        return icon
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let sizeHeader = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeHeader.isEnabled = false
        menu.addItem(sizeHeader)
        
        for size in NekoSize.allCases {
            let item = NSMenuItem(
                title: "  \(size.displayName)",
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

        let hideItem = NSMenuItem(
            title: "Hide Neko",
            action: #selector(toggleHidden),
            keyEquivalent: ""
        )
        hideItem.target = self
        hideItem.state = Settings.shared.isHidden ? .on : .off
        menu.addItem(hideItem)
        self.hideItem = hideItem

        if LoginItem.isSupported {
            let loginItem = NSMenuItem(
                title: "Launch at Login",
                action: #selector(toggleLaunchAtLogin),
                keyEquivalent: ""
            )
            loginItem.target = self
            loginItem.state = LoginItem.isEnabled ? .on : .off
            menu.addItem(loginItem)
            self.loginItem = loginItem
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Neko",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        menu.delegate = self
        statusItem.menu = menu
    }

    // Login state lives in System Settings, so re-read it every time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        hideItem?.state = Settings.shared.isHidden ? .on : .off
        loginItem?.state = LoginItem.isEnabled ? .on : .off
    }
    
    @objc private func sizeSelected(_ sender: NSMenuItem) {
        guard let menu = statusItem.menu,
              let size = NekoSize(rawValue: CGFloat(sender.tag)) else { return }
        
        for item in menu.items where item.tag > 0 {
            item.state = item.tag == sender.tag ? .on : .off
        }
        menu.update()
        Settings.shared.currentSize = size
    }
    
    @objc private func speedSelected(_ sender: NSMenuItem) {
        guard let menu = statusItem.menu,
              let speedValue = sender.representedObject as? Double,
              let speed = NekoSpeed(rawValue: speedValue) else { return }
        
        for item in menu.items {
            if item.representedObject is Double {
                item.state = item === sender ? .on : .off
            }
        }
        menu.update()
        Settings.shared.currentSpeed = speed
        onSpeedChange?()
    }

    @objc private func toggleHidden(_ sender: NSMenuItem) {
        Settings.shared.isHidden.toggle()
        sender.state = Settings.shared.isHidden ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        sender.state = LoginItem.isEnabled ? .on : .off

        if LoginItem.requiresApproval {
            LoginItem.openSettings()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

