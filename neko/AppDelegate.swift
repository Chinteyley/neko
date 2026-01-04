import Cocoa
import SwiftUI
import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var store: Store!
    private var statusBarController: StatusBarController!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let size = Settings.shared.currentSize.rawValue
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.center()

        store = Store(withMouseLoc: NSEvent.mouseLocation, andNekoLoc: window.frame.origin)
        
        window.contentView = NSHostingView(rootView: ContentView(store: store))
        window.makeKeyAndOrderFront(nil)
        
        Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { [weak self] _ in
            guard let self else { return }
            window.setFrameOrigin(store.nextTick(NSEvent.mouseLocation))
        }
        
        statusBarController = StatusBarController()
        
        Settings.shared.$currentSize
            .sink { [weak self] newSize in
                guard let self else { return }
                let sizeValue = newSize.rawValue
                window.setContentSize(NSSize(width: sizeValue, height: sizeValue))
            }
            .store(in: &cancellables)
    }
}
