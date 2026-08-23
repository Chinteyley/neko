import AppKit
import XCTest
@testable import neko

final class NekoCustomizationTests: XCTestCase {
    private var originalSize: NekoSize!
    private var originalSpeed: NekoSpeed!
    private var originalHidden: Bool!
    private var originalSign: NekoSign!

    override func setUp() {
        super.setUp()
        originalSize = Settings.shared.currentSize
        originalSpeed = Settings.shared.currentSpeed
        originalHidden = Settings.shared.isHidden
        originalSign = Settings.shared.currentSign
        Settings.shared.currentSize = .small
    }

    override func tearDown() {
        Settings.shared.currentSize = originalSize
        Settings.shared.currentSpeed = originalSpeed
        Settings.shared.isHidden = originalHidden
        Settings.shared.currentSign = originalSign
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

    func testStatusMenuUsesPlainSizeNamesAndOmitsDistanceAndRecovery() {
        let controller = StatusBarController()
        let menu = Mirror(reflecting: controller).children
            .compactMap { $0.label == "statusItem" ? $0.value as? NSStatusItem : nil }
            .first?.menu

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
            "Next Sign",
            "",
            "Hide Neko",
        ]
        if LoginItem.isSupported {
            expected.append("Launch at Login")
        }
        expected.append(contentsOf: ["", "Quit Neko"])

        XCTAssertEqual(menu?.items.map(\.title), expected)
    }

    func testSignPresetsCycleAndPersist() {
        XCTAssertEqual(NekoSign.allCases, [.stillLeftAligned, .yelledAt, .fortySeven])
        XCTAssertEqual(NekoSign.stillLeftAligned.text, "still left-aligned")
        XCTAssertEqual(NekoSign.yelledAt.text, "yelled at: 4")
        XCTAssertEqual(NekoSign.fortySeven.text, "$47")
        XCTAssertEqual(NekoSign.fromStoredValue(0), .stillLeftAligned)
        XCTAssertEqual(NekoSign.fromStoredValue(1), .yelledAt)
        XCTAssertEqual(NekoSign.fromStoredValue(2), .fortySeven)
        XCTAssertNil(NekoSign.fromStoredValue(99))

        Settings.shared.currentSign = .stillLeftAligned
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "nekoSign"), 0)

        Settings.shared.cycleSign()
        XCTAssertEqual(Settings.shared.currentSign, .yelledAt)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "nekoSign"), 1)

        Settings.shared.cycleSign()
        XCTAssertEqual(Settings.shared.currentSign, .fortySeven)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "nekoSign"), 2)

        Settings.shared.cycleSign()
        XCTAssertEqual(Settings.shared.currentSign, .stillLeftAligned)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "nekoSign"), 0)
    }

    func testNextSignMenuItemCyclesThePersistedLine() {
        Settings.shared.currentSign = .stillLeftAligned
        let controller = StatusBarController()
        let menu = Mirror(reflecting: controller).children
            .compactMap { $0.label == "statusItem" ? $0.value as? NSStatusItem : nil }
            .first?.menu
        let item = menu?.items.first { $0.title == "Next Sign" }

        guard let item, let action = item.action else {
            XCTFail("Expected Next Sign menu item")
            return
        }
        XCTAssertEqual(item.keyEquivalent, "s")
        controller.perform(action, with: item)
        XCTAssertEqual(Settings.shared.currentSign, .yelledAt)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "nekoSign"), 1)
    }

    func testSignHitTargetIncludesSpriteAndBubbleButNotEmptyPanel() {
        let size = NekoSize.small
        let frame = CGRect(origin: .zero, size: NekoSignMetrics.windowSize(for: size))

        XCTAssertTrue(NekoSignMetrics.contains(CGPoint(x: 8, y: 8), windowFrame: frame, size: size))
        XCTAssertTrue(NekoSignMetrics.contains(
            CGPoint(x: 20, y: size.rawValue + NekoSignMetrics.stickHeight + 2),
            windowFrame: frame,
            size: size
        ))
        XCTAssertFalse(NekoSignMetrics.contains(
            CGPoint(x: size.rawValue + 10, y: 4),
            windowFrame: frame,
            size: size
        ))
        XCTAssertFalse(NekoSignMetrics.contains(
            CGPoint(x: 40, y: size.rawValue + 1),
            windowFrame: frame,
            size: size
        ))
        XCTAssertFalse(NekoSignMetrics.contains(CGPoint(x: -1, y: 8), windowFrame: frame, size: size))
        XCTAssertGreaterThan(frame.width, size.rawValue)
        XCTAssertGreaterThan(frame.height, size.rawValue)
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
