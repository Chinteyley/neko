import Cocoa

final class StatusBarController {
    private var statusItem: NSStatusItem
    var onSpeedChange: (() -> Void)?
    var onToggleEnabled: (() -> Void)?
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // Safely unwrap applicationIconImage and ensure we have a non-optional NSImage
            let baseIcon = NSApplication.shared.applicationIconImage ?? NSImage(size: NSSize(width: 18, height: 18))
            let icon = baseIcon.copy() as? NSImage ?? baseIcon
            let iconSize = NSSize(
                width: NSStatusBar.system.thickness,
                height: NSStatusBar.system.thickness
            )
            icon.size = iconSize
            icon.isTemplate = false
            button.image = icon
            button.imagePosition = .imageOnly
            button.title = ""
        }
        
        setupMenu()
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
        let enableItem = NSMenuItem(
            title: Settings.shared.nekoEnabled ? "Pause Neko" : "Resume Neko",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: "p"
        )
        enableItem.target = self
        enableItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(enableItem)

        let quitItem = NSMenuItem(
            title: "Quit Neko",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
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

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        Settings.shared.nekoEnabled.toggle()
        sender.title = Settings.shared.nekoEnabled ? "Pause Neko" : "Resume Neko"
        statusItem.menu?.update()
        onToggleEnabled?()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

