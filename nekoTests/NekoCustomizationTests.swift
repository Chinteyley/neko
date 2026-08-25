import AppKit
import SwiftUI
import XCTest
@testable import neko

final class NekoCustomizationTests: XCTestCase {
    private var originalSize: NekoSize!
    private var originalSpeed: NekoSpeed!
    private var originalHidden: Bool!

    override func setUp() {
        super.setUp()
        originalSize = Settings.shared.currentSize
        originalSpeed = Settings.shared.currentSpeed
        originalHidden = Settings.shared.isHidden
        Settings.shared.currentSize = .small
    }

    override func tearDown() {
        Settings.shared.currentSize = originalSize
        Settings.shared.currentSpeed = originalSpeed
        Settings.shared.isHidden = originalHidden
        super.tearDown()
    }

    func testHiddenSettingPersists() {
        Settings.shared.isHidden = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "nekoHidden"))

        Settings.shared.isHidden = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "nekoHidden"))
    }

    func testAnimationTimerRunsWhileAMenuTracksEvents() {
        var ticks = 0
        let timer = makeNekoTimer(interval: 0.01) { ticks += 1 }
        defer { timer.invalidate() }

        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline, ticks == 0 {
            _ = RunLoop.current.run(mode: .eventTracking, before: deadline)
        }

        XCTAssertGreaterThan(ticks, 0)
    }

    func testTimerRestartedDuringEventTrackingKeepsFiringInDefaultMode() {
        var ticks = 0
        var timer = makeNekoTimer(interval: 0.01) { ticks += 1 }
        timer.invalidate()
        ticks = 0

        let trackingDeadline = Date().addingTimeInterval(0.2)
        var created = false
        while Date() < trackingDeadline {
            if !created {
                timer = makeNekoTimer(interval: 0.01) { ticks += 1 }
                created = true
            }
            _ = RunLoop.current.run(mode: .eventTracking, before: Date().addingTimeInterval(0.02))
        }
        XCTAssertGreaterThan(ticks, 0)

        let ticksAfterMenu = ticks
        let defaultDeadline = Date().addingTimeInterval(0.2)
        while Date() < defaultDeadline {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        XCTAssertGreaterThan(ticks, ticksAfterMenu)
        timer.invalidate()
    }

    func testPanelFrameSurvivesOrderOutAndKeepsMoving() {
        let panel = NSPanel(
            contentRect: NSRect(x: 240, y: 240, width: 32, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.orderFrontRegardless()

        let sizeBefore = panel.frame.size
        panel.orderOut(nil)
        let sizeWhileHidden = panel.frame.size
        panel.orderFrontRegardless()

        XCTAssertGreaterThan(sizeBefore.width, 0)
        XCTAssertEqual(sizeWhileHidden.width, sizeBefore.width, accuracy: 0.5)
        XCTAssertEqual(panel.frame.size.width, sizeBefore.width, accuracy: 0.5)

        let startX = panel.frame.origin.x
        var origin = panel.frame.origin
        var timer = makeNekoTimer(interval: 0.01) { }
        timer.invalidate()
        timer = makeNekoTimer(interval: 0.01) {
            origin.x += 4
            panel.setFrameOrigin(origin)
        }
        defer { timer.invalidate() }

        let deadline = Date().addingTimeInterval(0.25)
        while Date() < deadline {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        XCTAssertGreaterThan(panel.frame.origin.x, startX)
        panel.orderOut(nil)
    }

    func testHideByAlphaKeepsWalkingAfterUnhide() {
        Settings.shared.currentSize = .small
        let target = NSPoint(x: 400, y: 0)
        let store = Store(withMouseLoc: target, andNekoLoc: .zero)
        let panel = NSPanel(
            contentRect: NSRect(x: 300, y: 300, width: 16, height: 16),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.setFrameOrigin(.zero)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        var timer: Timer?
        func startTimer() {
            timer?.invalidate()
            timer = makeNekoTimer(interval: 0.01) {
                panel.setFrameOrigin(store.nextTick(target))
            }
        }
        startTimer()

        let warmup = Date().addingTimeInterval(0.12)
        while Date() < warmup {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        XCTAssertGreaterThan(store.tick, 0)

        timer?.invalidate()
        timer = nil
        panel.alphaValue = 0
        let originAtHide = store.nekoLoc

        panel.alphaValue = 1
        panel.level = .statusBar
        panel.orderFrontRegardless()
        startTimer()

        let resume = Date().addingTimeInterval(0.2)
        while Date() < resume {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        XCTAssertGreaterThan(store.nekoLoc.x, originAtHide.x)
        timer?.invalidate()
        panel.orderOut(nil)
    }

    func testHostingOverlayMovesOnScreenAfterHideUnhide() {
        Settings.shared.currentSize = .small
        let target = NSPoint(x: 1200, y: 200)
        let start = NSPoint(x: 200, y: 200)
        let store = Store(withMouseLoc: target, andNekoLoc: start)
        let size = NSSize(width: 16, height: 16)
        let panel = NSPanel(
            contentRect: NSRect(origin: start, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.backgroundColor = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0)
        panel.ignoresMouseEvents = true
        let hosting = NSHostingView(rootView: ContentView(store: store))
        disableHostingSizeControl(hosting)
        panel.contentView = hosting
        panel.setFrame(NSRect(origin: start, size: size), display: true)
        panel.orderFrontRegardless()

        var timer: Timer?
        func startTimer() {
            timer?.invalidate()
            timer = makeNekoTimer(interval: 0.01) {
                placeNeko(panel, at: store.nextTick(target), size: size)
            }
        }
        startTimer()

        let warmup = Date().addingTimeInterval(0.15)
        while Date() < warmup {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        XCTAssertGreaterThan(panel.frame.origin.x, start.x)

        timer?.invalidate()
        timer = nil
        panel.alphaValue = 0
        let originAtHide = panel.frame.origin

        panel.alphaValue = 1
        panel.level = .statusBar
        panel.orderFrontRegardless()
        startTimer()

        let resume = Date().addingTimeInterval(0.25)
        while Date() < resume {
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        XCTAssertGreaterThan(panel.frame.origin.x, originAtHide.x)
        timer?.invalidate()
        panel.orderOut(nil)
    }

    func testSizePresets() {
        XCTAssertEqual(NekoSize.allCases, [.small, .medium, .large])
        XCTAssertEqual(NekoSize.small.rawValue, 16)
        XCTAssertEqual(NekoSize.medium.rawValue, 24)
        XCTAssertEqual(NekoSize.large.rawValue, 32)
        XCTAssertEqual(NekoSize.fromSavedValue(16), .small)
        XCTAssertEqual(NekoSize.fromSavedValue(24), .medium)
        XCTAssertEqual(NekoSize.fromSavedValue(32), .large)
    }

    func testExactStopAndResumeBoundariesAtEverySize() {
        for size in NekoSize.allCases {
            Settings.shared.currentSize = size
            let stop = size.rawValue
            let resume = size.rawValue * 1.5
            let origin = NSPoint.zero

            let stopStore = Store(withMouseLoc: point(stop), andNekoLoc: origin)
            XCTAssertEqual(stopStore.nextTick(point(stop)), origin)
            assertIdle(stopStore)

            let resumeStore = Store(withMouseLoc: origin, andNekoLoc: origin)
            XCTAssertEqual(resumeStore.nextTick(point(resume)), origin)
            assertIdle(resumeStore)
            XCTAssertEqual(resumeStore.nextTick(point(resume + 0.01)), origin)
            assertAlert(resumeStore)
        }
    }

    func testHysteresisPreservesIdleAndMovingStateAtEverySize() {
        for size in NekoSize.allCases {
            Settings.shared.currentSize = size
            let stop = size.rawValue
            let resume = size.rawValue * 1.5
            let band = (stop + resume) / 2
            let origin = NSPoint.zero

            let idleStore = Store(withMouseLoc: origin, andNekoLoc: origin)
            XCTAssertEqual(idleStore.nextTick(point(band)), origin)
            assertIdle(idleStore)

            let movingStore = Store(
                withMouseLoc: point(resume + size.rawValue),
                andNekoLoc: origin
            )
            let expectedTravel = band - stop
            XCTAssertEqual(movingStore.nextTick(point(band)).x, expectedTravel, accuracy: 0.001)
            assertMovingEast(movingStore)
            XCTAssertEqual(movingStore.nextTick(point(band)).x, expectedTravel, accuracy: 0.001)
            assertThinking(movingStore)
        }
    }

    func testDirectMovementStopsAtSelectedRadiusWithoutZeroTravelGait() {
        Settings.shared.currentSize = .small
        let target = point(20)
        let store = Store(withMouseLoc: target, andNekoLoc: .zero)

        XCTAssertEqual(store.nextTick(target), point(4))
        assertMovingEast(store)
        XCTAssertEqual(store.nextTick(target), point(4))
        assertThinking(store)
    }

    func testDiagonalMovementStopsAtSelectedRadius() {
        Settings.shared.currentSize = .small
        let target = NSPoint(x: 19.2, y: 25.6)
        let store = Store(withMouseLoc: target, andNekoLoc: .zero)

        let moved = store.nextTick(target)
        XCTAssertEqual(moved.x, 9.6, accuracy: 0.001)
        XCTAssertEqual(moved.y, 12.8, accuracy: 0.001)
        assertMovingNorthEast(store)

        let stopped = store.nextTick(target)
        XCTAssertEqual(stopped.x, moved.x, accuracy: 0.001)
        XCTAssertEqual(stopped.y, moved.y, accuracy: 0.001)
        assertThinking(store)
    }

    func testDiagonalLeftoverDoesNotKeepWalkGait() {
        Settings.shared.currentSize = .small
        let mouse = NSPoint(x: 30, y: 40)
        let radius = Settings.shared.currentSize.rawValue + 1e-9
        let distance = hypot(mouse.x, mouse.y)
        let origin = NSPoint(
            x: mouse.x - mouse.x / distance * radius,
            y: mouse.y - mouse.y / distance * radius
        )
        let store = Store(withMouseLoc: mouse, andNekoLoc: origin)

        XCTAssertEqual(store.nextTick(mouse), origin)
        XCTAssertFalse(isMoving(store))
        assertThinking(store)
    }

    func testMouseInsideFarCornerArrivesInsteadOfWalking() {
        Settings.shared.currentSize = .small
        let mouse = NSPoint(x: 15, y: 15)
        let store = Store(withMouseLoc: mouse, andNekoLoc: .zero)

        XCTAssertEqual(store.nextTick(mouse), .zero)
        XCTAssertFalse(isMoving(store))
        assertThinking(store)
    }

    func testSubpixelMouseJitterDoesNotCancelThinking() {
        Settings.shared.currentSize = .small
        let target = point(20)
        let store = Store(withMouseLoc: target, andNekoLoc: .zero)
        _ = store.nextTick(target)
        _ = store.nextTick(target)
        assertThinking(store)

        let jittered = NSPoint(x: target.x + 0.25, y: target.y + 0.25)
        XCTAssertEqual(store.nextTick(jittered), store.nekoLoc)
        assertThinking(store)
    }

    func testStatusItemUsesFilledIconWhenVisibleAndOutlineWhenHidden() {
        Settings.shared.isHidden = false
        let controller = StatusBarController()
        let button = statusItem(from: controller)?.button
        let visible = button?.image
        XCTAssertNotNil(visible)
        XCTAssertTrue(visible?.isTemplate ?? false)

        Settings.shared.isHidden = true
        let hidden = button?.image
        XCTAssertNotNil(hidden)
        XCTAssertTrue(hidden?.isTemplate ?? false)
        XCTAssertGreaterThan(opaquePixelCount(visible), opaquePixelCount(hidden))

        Settings.shared.isHidden = false
        XCTAssertEqual(opaquePixelCount(button?.image), opaquePixelCount(visible))
    }

    func testStatusMenuUsesPlainSizeNamesAndOmitsDistanceAndRecovery() {
        let controller = StatusBarController()
        let menu = statusItem(from: controller)?.menu

        var expected = [
            "Size",
            "  Small",
            "  Medium",
            "  Large",
            "",
            "Speed",
            "  Slow",
            "  Normal",
            "  Fast",
            "",
            "Hide Neko",
        ]
        if LoginItem.isSupported {
            expected.append("Launch at Login")
        }
        expected.append(contentsOf: ["", "Quit Neko"])

        XCTAssertEqual(menu?.items.map(\.title), expected)
    }

    private func statusItem(from controller: StatusBarController) -> NSStatusItem? {
        Mirror(reflecting: controller).children
            .compactMap { $0.label == "statusItem" ? $0.value as? NSStatusItem : nil }
            .first
    }

    private func opaquePixelCount(_ image: NSImage?) -> Int {
        guard let image,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return 0 }
        var count = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.5 {
                    count += 1
                }
            }
        }
        return count
    }

    private func point(_ x: CGFloat) -> NSPoint {
        NSPoint(x: x, y: 0)
    }

    private func isMoving(_ store: Store) -> Bool {
        store.anim.contains { state in
            switch state {
            case .movingNorthWest1, .movingNorthWest2,
                 .movingNorth1, .movingNorth2,
                 .movingNorthEast1, .movingNorthEast2,
                 .movingEast1, .movingEast2,
                 .movingSouthEast1, .movingSouthEast2,
                 .movingSouth1, .movingSouth2,
                 .movingSouthWest1, .movingSouthWest2,
                 .movingWest1, .movingWest2:
                return true
            default:
                return false
            }
        }
    }

    private func assertIdle(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 1, case .idle = store.anim[0] else {
            XCTFail("Expected idle animation", file: file, line: line)
            return
        }
    }

    private func assertAlert(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 1, case .alert = store.anim[0] else {
            XCTFail("Expected alert animation", file: file, line: line)
            return
        }
    }

    private func assertThinking(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 1, case .thinking = store.anim[0] else {
            XCTFail("Expected thinking animation", file: file, line: line)
            return
        }
    }

    private func assertMovingEast(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 2,
              case .movingEast1 = store.anim[0],
              case .movingEast2 = store.anim[1] else {
            XCTFail("Expected east movement animation", file: file, line: line)
            return
        }
    }

    private func assertMovingNorthEast(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 2,
              case .movingNorthEast1 = store.anim[0],
              case .movingNorthEast2 = store.anim[1] else {
            XCTFail("Expected northeast movement animation", file: file, line: line)
            return
        }
    }
}
