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

        window.backgroundColor = NSColor.init(calibratedRed: 1, green: 1, blue: 1, alpha: 0)
        window.ignoresMouseEvents = true
        installContentView()
        placeNeko(window, at: window.frame.origin, size: NSSize(width: initialSize, height: initialSize))

        startAnimationTimer()
        if Settings.shared.isHidden {
            window.alphaValue = 0
        } else {
            window.orderFrontRegardless()
        }
        
        statusBarController = StatusBarController()
        statusBarController?.onSpeedChange = { [weak self] in
            self?.startAnimationTimer()
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

        Settings.shared.$isHidden
            .dropFirst()
            .sink { [weak self] hidden in
                self?.applyHidden(hidden)
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
        placeNeko(window, at: origin, size: window.frame.size)
    }

    private func applyHidden(_ hidden: Bool) {
        if hidden {
            window.alphaValue = 0
        } else {
            let size = NSSize(
                width: Settings.shared.currentSize.rawValue,
                height: Settings.shared.currentSize.rawValue
            )
            let parkedOrigin = window.frame.origin
            if hypot(store.nekoLoc.x - parkedOrigin.x, store.nekoLoc.y - parkedOrigin.y) > 0.5 {
                store.relocate(to: parkedOrigin, mouseLocation: NSEvent.mouseLocation)
            }
            let origin = originAfterUnhide(
                parkedOrigin: parkedOrigin,
                parkedSize: size,
                mouseLocation: NSEvent.mouseLocation,
                visibleFrames: NSScreen.screens.map(\.visibleFrame)
            )
            if origin != store.nekoLoc {
                store.relocate(to: origin, mouseLocation: NSEvent.mouseLocation)
            }
            placeNeko(window, at: origin, size: size)
            window.alphaValue = 1
            window.level = .statusBar
            window.orderFrontRegardless()
        }
        startAnimationTimer(isHidden: hidden)
    }

    private func installContentView() {
        let hosting = NSHostingView(rootView: ContentView(store: store))
        disableHostingSizeControl(hosting)
        window.contentView = hosting
    }

    private func updateWindowSize(_ size: NekoSize) {
        placeNeko(
            window,
            at: window.frame.origin,
            size: NSSize(width: size.rawValue, height: size.rawValue)
        )
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard requiresNekoRecovery(window.frame, in: visibleFrames) else { return }
        bringNekoHere()
    }

    private func startAnimationTimer(isHidden: Bool = Settings.shared.isHidden) {
        animationTimer?.invalidate()
        animationTimer = nil
        guard !isHidden else { return }

        animationTimer = makeNekoTimer(interval: Settings.shared.currentSpeed.rawValue) { [weak self] in
            guard let self = self else { return }
            let mouseLocation = NSEvent.mouseLocation
            let frames = NSScreen.screens.map(\.visibleFrame)
            let nextOrigin = self.store.nextTick(mouseLocation, visibleFrames: frames)
            placeNeko(
                self.window,
                at: nextOrigin,
                size: self.window.frame.size
            )
        }
    }
}

// Menu tracking runs the main loop in .eventTracking, which a default-mode timer
// never reaches; the neko would freeze for as long as the menu stayed open.
func disableHostingSizeControl<Content: View>(_ hosting: NSHostingView<Content>) {
    if #available(macOS 13.0, *) {
        hosting.sizingOptions = []
    }
}

func placeNeko(_ window: NSWindow, at origin: NSPoint, size: NSSize) {
    let width = size.width > 0 ? size.width : Settings.shared.currentSize.rawValue
    let height = size.height > 0 ? size.height : Settings.shared.currentSize.rawValue
    window.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
}

func makeNekoTimer(interval: TimeInterval, tick: @escaping () -> Void) -> Timer {
    let timer = Timer(timeInterval: interval, repeats: true) { _ in tick() }
    RunLoop.main.add(timer, forMode: .default)
    RunLoop.main.add(timer, forMode: .common)
    RunLoop.main.add(timer, forMode: .eventTracking)
    return timer
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

func originAfterUnhide(
    parkedOrigin: NSPoint,
    parkedSize: NSSize,
    mouseLocation: NSPoint,
    visibleFrames: [NSRect]
) -> NSPoint {
    let parked = NSRect(origin: parkedOrigin, size: parkedSize)
    if !requiresNekoRecovery(parked, in: visibleFrames) {
        return parkedOrigin
    }

    guard let visibleFrame = visibleFrames.first(where: { $0.contains(mouseLocation) })
            ?? visibleFrames.first else {
        return parkedOrigin
    }
    return clampedNekoOrigin(
        mouseLocation: mouseLocation,
        windowSize: parkedSize,
        visibleFrame: visibleFrame
    )
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

