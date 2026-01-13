import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!
    var animationTimer: Timer?
    var statusBarController: StatusBarController?
    private var store: Store!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        let initialSize = Settings.shared.currentSize.rawValue
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialSize, height: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.center()

        store = Store(withMouseLoc: NSEvent.mouseLocation, andNekoLoc: window.frame.origin)
        let contentView = ContentView(store: store)
        let hostingView = NSHostingView(rootView: contentView)

        window.backgroundColor = NSColor.init(calibratedRed: 1, green: 1, blue: 1, alpha: 0)
        window.ignoresMouseEvents = true
        window.contentView = hostingView

        startAnimationTimer()
        window.orderFrontRegardless()
        
        statusBarController = StatusBarController()
        statusBarController?.onSpeedChange = { [weak self] in
            self?.restartAnimationTimer()
        }
        statusBarController?.onToggleEnabled = { [weak self] in
            if Settings.shared.nekoEnabled {
                self?.resumeNeko()
            } else {
                self?.pauseNeko()
            }
        }
        
        Settings.shared.$currentSize
            .dropFirst()
            .sink { [weak self] newSize in
                self?.updateWindowSize(newSize)
            }
            .store(in: &cancellables)
    }
    
    private func updateWindowSize(_ size: NekoSize) {
        let newSize = size.rawValue
        window.setContentSize(NSSize(width: newSize, height: newSize))
    }

    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: Settings.shared.currentSpeed.rawValue, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.window.setFrameOrigin(self.store.nextTick(NSEvent.mouseLocation))
            }
        }
    }

    private func restartAnimationTimer() {
        animationTimer?.invalidate()
        startAnimationTimer()
    }

    func pauseNeko() {
        animationTimer?.invalidate()
        animationTimer = nil
        window.orderOut(nil)
    }

    func resumeNeko() {
        window.orderFrontRegardless()
        startAnimationTimer()
    }
}

