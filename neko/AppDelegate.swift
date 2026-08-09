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
        
        if !Settings.shared.nekoEnabled {
            pauseNeko()
        }
        
        statusBarController = StatusBarController()
        statusBarController?.onSpeedChange = { [weak self] in
            guard Settings.shared.nekoEnabled else { return }
            self?.restartAnimationTimer()
        }
        statusBarController?.onBringNekoHere = { [weak self] in
            self?.bringNekoHere()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: NSApp
        )
        
        Settings.shared.$currentSize
            .dropFirst()
            .sink { [weak self] newSize in
                self?.updateWindowSize(newSize)
            }
            .store(in: &cancellables)
        
        Settings.shared.$nekoEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.resumeNeko()
                } else {
                    self?.pauseNeko()
                }
            }
            .store(in: &cancellables)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: NSApp
        )
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard !isNekoFrameVisible(window.frame, in: visibleFrames) else { return }
        bringNekoHere()
    }

    private func bringNekoHere() {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        guard let screen = screens.first(where: { $0.frame.contains(mouseLocation) }) ?? screens.first else { return }

        let origin = clampedNekoOrigin(
            mouseLocation: mouseLocation,
            windowSize: window.frame.size,
            visibleFrame: screen.visibleFrame
        )
        store.relocate(to: origin, mouseLocation: mouseLocation)
        window.setFrameOrigin(origin)
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

func clampedNekoOrigin(mouseLocation: NSPoint, windowSize: NSSize, visibleFrame: NSRect) -> NSPoint {
    let centered = NSPoint(
        x: mouseLocation.x - windowSize.width / 2,
        y: mouseLocation.y - windowSize.height / 2
    )
    let maxX = max(visibleFrame.minX, visibleFrame.maxX - windowSize.width)
    let maxY = max(visibleFrame.minY, visibleFrame.maxY - windowSize.height)

    return NSPoint(
        x: min(max(centered.x, visibleFrame.minX), maxX),
        y: min(max(centered.y, visibleFrame.minY), maxY)
    )
}

func isNekoFrameVisible(_ frame: NSRect, in visibleFrames: [NSRect]) -> Bool {
    visibleFrames.contains { $0.contains(frame) }
}

