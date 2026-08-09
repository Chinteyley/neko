import XCTest
@testable import neko

final class StoreThinkingTests: XCTestCase {
    private var originalSize: NekoSize!
    private var originalSpeed: NekoSpeed!
    private var originalFollowDistance: NekoFollowDistance!

    override func setUp() {
        super.setUp()
        originalSize = Settings.shared.currentSize
        originalSpeed = Settings.shared.currentSpeed
        originalFollowDistance = Settings.shared.currentFollowDistance
        Settings.shared.currentSize = .small
        Settings.shared.currentFollowDistance = .close
    }

    override func tearDown() {
        Settings.shared.currentSize = originalSize
        Settings.shared.currentSpeed = originalSpeed
        Settings.shared.currentFollowDistance = originalFollowDistance
        super.tearDown()
    }

    func testArrivalThinksForApproximatelyPointSixSecondsAtEverySpeed() {
        let cases: [(NekoSpeed, Int)] = [(.slow, 3), (.normal, 4), (.fast, 6)]

        for (speed, displayedTicks) in cases {
            let store = arrivedStore(speed: speed)
            assertThinking(store)

            for _ in 1..<displayedTicks {
                _ = store.nextTick(arrival)
                assertThinking(store)
            }

            _ = store.nextTick(arrival)
            assertIdle(store)
            XCTAssertEqual(Settings.shared.currentSpeed.rawValue, speed.rawValue)
        }
    }

    func testSlowToFastSpeedChangeKeepsThinkingForApproximatelyPointSixSeconds() {
        let store = arrivedStore(speed: .slow)
        assertThinking(store)
        Settings.shared.currentSpeed = .fast

        for _ in 0..<5 {
            _ = store.nextTick(arrival)
            assertThinking(store)
        }

        _ = store.nextTick(arrival)
        assertIdle(store)
    }

    func testFastToSlowSpeedChangeKeepsThinkingForApproximatelyPointSevenSeconds() {
        let store = arrivedStore(speed: .fast)
        assertThinking(store)
        Settings.shared.currentSpeed = .slow

        for _ in 0..<2 {
            _ = store.nextTick(arrival)
            assertThinking(store)
        }

        _ = store.nextTick(arrival)
        assertIdle(store)
    }

    func testAnyCursorMovementCancelsThinkingImmediately() {
        let store = arrivedStore(speed: .normal)
        assertThinking(store)
        let location = store.nekoLoc

        _ = store.nextTick(NSPoint(x: arrival.x + 1, y: arrival.y))

        assertIdle(store)
        XCTAssertEqual(store.nekoLoc, location)
    }

    func testMovementAfterThinkingPreservesAlertAndDirectCrispStep() {
        let store = arrivedStore(speed: .normal)
        assertThinking(store)
        let location = store.nekoLoc
        let target = NSPoint(x: location.x + Settings.shared.currentSize.rawValue * 2, y: location.y)

        _ = store.nextTick(target)

        assertAlert(store)
        XCTAssertEqual(store.nekoLoc, location)

        _ = store.nextTick(target)

        assertMovingEast(store)
        XCTAssertEqual(store.nekoLoc.x, location.x + Settings.shared.currentSize.rawValue)
        XCTAssertEqual(store.nekoLoc.y, location.y)
    }

    func testIdleProgressionReachesGroomingAfterThinking() {
        let store = arrivedStore(speed: .normal)

        for _ in 1..<4 {
            _ = store.nextTick(arrival)
            assertThinking(store)
        }

        _ = store.nextTick(arrival)
        assertIdle(store)

        for _ in 0..<7 {
            _ = store.nextTick(arrival)
            assertIdle(store)
        }

        _ = store.nextTick(arrival)
        assertGrooming(store)
    }

    private var arrival: NSPoint {
        NSPoint(x: Settings.shared.currentSize.rawValue * 3, y: 0)
    }

    private func arrivedStore(speed: NekoSpeed) -> Store {
        Settings.shared.currentSpeed = speed
        let store = Store(withMouseLoc: arrival, andNekoLoc: NSPoint(x: 0, y: 0))
        _ = store.nextTick(arrival)
        _ = store.nextTick(arrival)
        _ = store.nextTick(arrival)
        return store
    }

    private func assertThinking(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 1, case .thinking = store.anim[0] else {
            XCTFail("Expected thinking animation", file: file, line: line)
            return
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

    private func assertMovingEast(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 2,
              case .movingEast1 = store.anim[0],
              case .movingEast2 = store.anim[1] else {
            XCTFail("Expected east movement animation", file: file, line: line)
            return
        }
    }

    private func assertGrooming(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 2,
              case .grooming1 = store.anim[0],
              case .grooming2 = store.anim[1] else {
            XCTFail("Expected grooming animation", file: file, line: line)
            return
        }
    }
}
