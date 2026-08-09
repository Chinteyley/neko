import AppKit
import SwiftUI
import XCTest
@testable import neko

final class NekoCustomizationTests: XCTestCase {
    private var originalSize: NekoSize!
    private var originalSpeed: NekoSpeed!
    private var originalFollowDistance: NekoFollowDistance!
    private var originalTheme: NekoTheme!
    private var storedFollowDistance: Any?
    private var storedTheme: Any?

    override func setUp() {
        super.setUp()
        originalSize = Settings.shared.currentSize
        originalSpeed = Settings.shared.currentSpeed
        originalFollowDistance = Settings.shared.currentFollowDistance
        originalTheme = Settings.shared.currentTheme
        storedFollowDistance = UserDefaults.standard.object(forKey: "nekoFollowDistance")
        storedTheme = UserDefaults.standard.object(forKey: "nekoTheme")
        Settings.shared.currentSize = .small
        Settings.shared.currentFollowDistance = .close
        Settings.shared.currentTheme = .classic
    }

    override func tearDown() {
        Settings.shared.currentSize = originalSize
        Settings.shared.currentSpeed = originalSpeed
        Settings.shared.currentFollowDistance = originalFollowDistance
        Settings.shared.currentTheme = originalTheme
        restore(storedFollowDistance, forKey: "nekoFollowDistance")
        restore(storedTheme, forKey: "nekoTheme")
        super.tearDown()
    }

    func testCustomizationEnumsHaveStableValuesAndFallbacks() {
        XCTAssertEqual(NekoFollowDistance.allCases, [.close, .comfortable, .far])
        XCTAssertEqual(NekoFollowDistance.close.rawValue, "close")
        XCTAssertEqual(NekoFollowDistance.comfortable.rawValue, "comfortable")
        XCTAssertEqual(NekoFollowDistance.far.rawValue, "far")
        XCTAssertEqual(NekoFollowDistance.close.stopMultiplier, 1)
        XCTAssertEqual(NekoFollowDistance.close.resumeMultiplier, 1.5)
        XCTAssertEqual(NekoFollowDistance.comfortable.stopMultiplier, 3)
        XCTAssertEqual(NekoFollowDistance.comfortable.resumeMultiplier, 3.5)
        XCTAssertEqual(NekoFollowDistance.far.stopMultiplier, 6)
        XCTAssertEqual(NekoFollowDistance.far.resumeMultiplier, 6.5)
        XCTAssertEqual(NekoFollowDistance.fromStoredValue("far"), .far)
        XCTAssertEqual(NekoFollowDistance.fromStoredValue(nil), .close)
        XCTAssertEqual(NekoFollowDistance.fromStoredValue("unknown"), .close)

        XCTAssertEqual(NekoTheme.allCases, [.classic, .ginger, .blueGray])
        XCTAssertEqual(NekoTheme.classic.rawValue, "classic")
        XCTAssertEqual(NekoTheme.ginger.rawValue, "ginger")
        XCTAssertEqual(NekoTheme.blueGray.rawValue, "blueGray")
        XCTAssertEqual(NekoTheme.fromStoredValue("ginger"), .ginger)
        XCTAssertEqual(NekoTheme.fromStoredValue(nil), .classic)
        XCTAssertEqual(NekoTheme.fromStoredValue("unknown"), .classic)
    }

    func testExactStopAndResumeBoundariesAtEverySizeAndDistance() {
        for size in NekoSize.allCases {
            Settings.shared.currentSize = size

            for distance in NekoFollowDistance.allCases {
                Settings.shared.currentFollowDistance = distance
                let stop = size.rawValue * distance.stopMultiplier
                let resume = size.rawValue * distance.resumeMultiplier
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
    }

    func testHysteresisPreservesIdleAndMovingStateAtEverySizeAndDistance() {
        for size in NekoSize.allCases {
            Settings.shared.currentSize = size

            for distance in NekoFollowDistance.allCases {
                Settings.shared.currentFollowDistance = distance
                let stop = size.rawValue * distance.stopMultiplier
                let resume = size.rawValue * distance.resumeMultiplier
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
    }

    func testDirectMovementStopsAtSelectedRadiusWithoutZeroTravelGait() {
        Settings.shared.currentSize = .small
        Settings.shared.currentFollowDistance = .close
        let target = point(20)
        let store = Store(withMouseLoc: target, andNekoLoc: .zero)

        XCTAssertEqual(store.nextTick(target), point(4))
        assertMovingEast(store)
        XCTAssertEqual(store.nextTick(target), point(4))
        assertThinking(store)
    }

    func testDiagonalMovementStopsAtSelectedRadius() {
        Settings.shared.currentSize = .small
        Settings.shared.currentFollowDistance = .close
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

    func testSmallerRuntimeDistanceStartsFollowingOnNextTick() {
        Settings.shared.currentSize = .small
        Settings.shared.currentFollowDistance = .far
        let target = point(40)
        let store = Store(withMouseLoc: .zero, andNekoLoc: .zero)

        XCTAssertEqual(store.nextTick(target), .zero)
        assertIdle(store)

        Settings.shared.currentFollowDistance = .close
        XCTAssertEqual(store.nextTick(target), .zero)
        assertAlert(store)
        XCTAssertEqual(store.nextTick(target), point(16))
        assertMovingEast(store)
    }

    func testLargerRuntimeDistanceStopsFollowingOnNextTick() {
        Settings.shared.currentSize = .small
        Settings.shared.currentFollowDistance = .close
        let target = point(100)
        let store = Store(withMouseLoc: target, andNekoLoc: .zero)

        XCTAssertEqual(store.nextTick(target), point(16))
        assertMovingEast(store)

        Settings.shared.currentFollowDistance = .far
        XCTAssertEqual(store.nextTick(target), point(16))
        assertThinking(store)
    }

    func testFollowDistanceMenuSelectorIsIsolatedAndPersistsEveryChoice() {
        Settings.shared.currentSize = .large
        Settings.shared.currentSpeed = .fast
        Settings.shared.currentTheme = .ginger
        let controller = StatusBarController()

        for distance in NekoFollowDistance.allCases {
            let sender = NSMenuItem()
            sender.representedObject = distance
            let sent = NSApp.sendAction(
                NSSelectorFromString("followDistanceSelected:"),
                to: controller,
                from: sender
            )

            XCTAssertTrue(sent)
            XCTAssertEqual(Settings.shared.currentFollowDistance, distance)
            XCTAssertEqual(UserDefaults.standard.string(forKey: "nekoFollowDistance"), distance.rawValue)
            XCTAssertEqual(Settings.shared.currentSize, .large)
            XCTAssertEqual(Settings.shared.currentSpeed, .fast)
            XCTAssertEqual(Settings.shared.currentTheme, .ginger)
        }
    }

    func testThemeMenuSelectorIsIsolatedAndPersistsEveryChoice() {
        Settings.shared.currentSize = .large
        Settings.shared.currentSpeed = .fast
        Settings.shared.currentFollowDistance = .comfortable
        let controller = StatusBarController()

        for theme in NekoTheme.allCases {
            let sender = NSMenuItem()
            sender.representedObject = theme
            let sent = NSApp.sendAction(
                NSSelectorFromString("themeSelected:"),
                to: controller,
                from: sender
            )

            XCTAssertTrue(sent)
            XCTAssertEqual(Settings.shared.currentTheme, theme)
            XCTAssertEqual(UserDefaults.standard.string(forKey: "nekoTheme"), theme.rawValue)
            XCTAssertEqual(Settings.shared.currentSize, .large)
            XCTAssertEqual(Settings.shared.currentSpeed, .fast)
            XCTAssertEqual(Settings.shared.currentFollowDistance, .comfortable)
        }
    }

    func testThemeColorsAreOpaqueAndMatchTheBuiltInPalette() {
        assertColor(NekoTheme.classic.color, red: 1, green: 1, blue: 1)
        assertColor(NekoTheme.ginger.color, red: 233 / 255, green: 149 / 255, blue: 69 / 255)
        assertColor(NekoTheme.blueGray.color, red: 130 / 255, green: 156 / 255, blue: 176 / 255)
    }

    private func point(_ x: CGFloat) -> NSPoint {
        NSPoint(x: x, y: 0)
    }

    private func restore(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func assertColor(
        _ color: Color,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else {
            XCTFail("Expected sRGB color", file: file, line: line)
            return
        }
        XCTAssertEqual(converted.redComponent, red, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(converted.greenComponent, green, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(converted.blueComponent, blue, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(converted.alphaComponent, 1, accuracy: 0.001, file: file, line: line)
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
