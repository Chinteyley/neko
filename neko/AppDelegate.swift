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
        window.isFloatingPanel = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        if #available(macOS 13.0, *) {
            window.collectionBehavior.insert(.canJoinAllApplications)
        }
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
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard requiresNekoRecovery(window.frame, in: visibleFrames) else { return }
        bringNekoHere()
    }

    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: Settings.shared.currentSpeed.rawValue, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let frames = NSScreen.screens.map(\.visibleFrame)
            self.window.setFrameOrigin(self.store.nextTick(NSEvent.mouseLocation, visibleFrames: frames))
        }
    }

    private func restartAnimationTimer() {
        animationTimer?.invalidate()
        startAnimationTimer()
    }
}

func clampOrigin(_ origin: NSPoint, size: NSSize, to visibleFrame: NSRect) -> NSPoint {
    let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
    let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)

    return NSPoint(
        x: min(max(origin.x, visibleFrame.minX), maxX),
        y: min(max(origin.y, visibleFrame.minY), maxY)
    )
}

func constrainNekoOrigin(
    proposed: NSPoint,
    current: NSPoint,
    size: NSSize,
    mouse: NSPoint,
    visibleFrames: [NSRect]
) -> NSPoint {
    guard !visibleFrames.isEmpty else { return proposed }

    let proposedFrame = NSRect(origin: proposed, size: size)
    if visibleFrames.contains(where: { $0.contains(proposedFrame) }) {
        return proposed
    }

    if let mouseFrame = visibleFrames.first(where: { $0.contains(mouse) && $0.intersects(proposedFrame) }) {
        return clampOrigin(proposed, size: size, to: mouseFrame)
    }

    let currentFrame = NSRect(origin: current, size: size)
    if let currentFrameVisible = visibleFrames.first(where: { $0.intersects(currentFrame) }) {
        return clampOrigin(proposed, size: size, to: currentFrameVisible)
    }

    let currentCenter = NSPoint(x: current.x + size.width / 2, y: current.y + size.height / 2)
    guard let nearest = visibleFrames.min(by: { a, b in
        hypot(a.midX - currentCenter.x, a.midY - currentCenter.y) < hypot(b.midX - currentCenter.x, b.midY - currentCenter.y)
    }) else {
        return proposed
    }
    return clampOrigin(proposed, size: size, to: nearest)
}

func clampedNekoOrigin(mouseLocation: NSPoint, windowSize: NSSize, visibleFrame: NSRect) -> NSPoint {
    let centered = NSPoint(
        x: mouseLocation.x - windowSize.width / 2,
        y: mouseLocation.y - windowSize.height / 2
    )
    return clampOrigin(centered, size: windowSize, to: visibleFrame)
}

func isNekoFrameVisible(_ frame: NSRect, in visibleFrames: [NSRect]) -> Bool {
    visibleFrames.contains { $0.contains(frame) }
}

func requiresNekoRecovery(_ frame: NSRect, in visibleFrames: [NSRect]) -> Bool {
    !isNekoFrameVisible(frame, in: visibleFrames)
}

