import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var animationTimer: Timer?
    var statusBarController: StatusBarController?
    private var store: Store!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 16, height: 16),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.level = NSWindow.Level.mainMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.center()

        store = Store(withMouseLoc: NSEvent.mouseLocation, andNekoLoc: window.frame.origin)
        let contentView = ContentView(store: store)
        let hostingView = NSHostingView(rootView: contentView)

        window.backgroundColor = NSColor.init(calibratedRed: 1, green: 1, blue: 1, alpha: 0)
        window.ignoresMouseEvents = true
        window.contentView = hostingView

        startAnimationTimer()
        window.makeKeyAndOrderFront(nil)

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
        window.makeKeyAndOrderFront(nil)
        startAnimationTimer()
    }
}
