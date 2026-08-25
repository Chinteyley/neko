import XCTest
@testable import neko

final class NekoPlacementTests: XCTestCase {
    private var originalSize: NekoSize!

    override func setUp() {
        super.setUp()
        originalSize = Settings.shared.currentSize
        Settings.shared.currentSize = .small
    }

    override func tearDown() {
        Settings.shared.currentSize = originalSize
        super.tearDown()
    }

    func testPlacementCentersPanelInsideVisibleFrame() {
        let origin = clampedNekoOrigin(
            mouseLocation: NSPoint(x: 500, y: 400),
            windowSize: NSSize(width: 20, height: 20),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        XCTAssertEqual(origin, NSPoint(x: 490, y: 390))
    }

    func testPlacementClampsAtVisibleFrameEdges() {
        let visibleFrame = NSRect(x: 0, y: 25, width: 1000, height: 750)
        let windowSize = NSSize(width: 20, height: 20)

        XCTAssertEqual(
            clampedNekoOrigin(
                mouseLocation: NSPoint(x: 0, y: 0),
                windowSize: windowSize,
                visibleFrame: visibleFrame
            ),
            NSPoint(x: 0, y: 25)
        )
        XCTAssertEqual(
            clampedNekoOrigin(
                mouseLocation: NSPoint(x: 1000, y: 800),
                windowSize: windowSize,
                visibleFrame: visibleFrame
            ),
            NSPoint(x: 980, y: 755)
        )
    }

    func testPlacementClampsInsideNegativeOriginVisibleFrame() {
        let origin = clampedNekoOrigin(
            mouseLocation: NSPoint(x: -1920, y: 0),
            windowSize: NSSize(width: 32, height: 32),
            visibleFrame: NSRect(x: -1920, y: 23, width: 1920, height: 1057)
        )

        XCTAssertEqual(origin, NSPoint(x: -1920, y: 23))
    }

    func testVisibilityRequiresCompleteContainment() {
        let visibleFrame = NSRect(x: 0, y: 25, width: 1000, height: 750)

        XCTAssertTrue(isNekoFrameVisible(NSRect(x: 10, y: 30, width: 20, height: 20), in: [visibleFrame]))
        XCTAssertFalse(isNekoFrameVisible(NSRect(x: 990, y: 30, width: 20, height: 20), in: [visibleFrame]))
    }

    func testResizeRecoveryIsRequiredOnlyWhenGrowthClipsTheNewFrame() {
        let visibleFrames = [
            NSRect(x: -200, y: 0, width: 200, height: 100),
            NSRect(x: 0, y: 0, width: 100, height: 100)
        ]
        let edgeSmallFrame = NSRect(x: 84, y: 84, width: 16, height: 16)
        let edgeLargeFrame = NSRect(x: 84, y: 68, width: 32, height: 32)
        let centeredLargeFrame = NSRect(x: 34, y: 34, width: 32, height: 32)

        XCTAssertFalse(requiresNekoRecovery(edgeSmallFrame, in: visibleFrames))
        XCTAssertTrue(requiresNekoRecovery(edgeLargeFrame, in: visibleFrames))
        XCTAssertFalse(requiresNekoRecovery(centeredLargeFrame, in: visibleFrames))
    }

    func testUnhideKeepsParkedOriginWhenFrameIsStillOnScreen() {
        let parked = NSPoint(x: 80, y: 90)
        let origin = originAfterUnhide(
            parkedOrigin: parked,
            parkedSize: NSSize(width: 16, height: 16),
            mouseLocation: NSPoint(x: 500, y: 400),
            visibleFrames: [NSRect(x: 0, y: 0, width: 1000, height: 800)]
        )
        XCTAssertEqual(origin, parked)
    }

    func testUnhideRecentersWhenParkedDisplayIsGone() {
        let remaining = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        let mouse = NSPoint(x: 2500, y: 400)
        let origin = originAfterUnhide(
            parkedOrigin: NSPoint(x: 80, y: 90),
            parkedSize: NSSize(width: 16, height: 16),
            mouseLocation: mouse,
            visibleFrames: [remaining]
        )
        XCTAssertEqual(
            origin,
            clampedNekoOrigin(
                mouseLocation: mouse,
                windowSize: NSSize(width: 16, height: 16),
                visibleFrame: remaining
            )
        )
    }

    func testUnhideWithoutRelocateResumesWalking() {
        let far = NSPoint(x: 80, y: 0)
        let store = Store(withMouseLoc: far, andNekoLoc: .zero)
        let mid = store.nextTick(far)
        XCTAssertNotEqual(mid, .zero)

        let resumed = store.nextTick(far)
        XCTAssertNotEqual(resumed, mid)
    }

    func testRelocateClearsThinkingAndStartsPursuitFromNewLocation() {
        let arrival = NSPoint(x: 32, y: 0)
        let store = Store(withMouseLoc: arrival, andNekoLoc: NSPoint(x: 0, y: 0))
        _ = store.nextTick(arrival)
        _ = store.nextTick(arrival)
        _ = store.nextTick(arrival)
        assertThinking(store)

        let location = NSPoint(x: 100, y: 100)
        store.relocate(to: location, mouseLocation: location)

        XCTAssertEqual(store.nekoLoc, location)
        XCTAssertEqual(store.mouseLoc, location)
        XCTAssertEqual(store.tick, 0)
        assertIdle(store)
        XCTAssertEqual(store.nextTick(location), location)

        let target = NSPoint(x: 132, y: 100)
        XCTAssertEqual(store.nextTick(target), location)
        XCTAssertEqual(store.nextTick(target), NSPoint(x: 116, y: 100))
    }

    func testRelocateResetsIdleProgression() {
        let location = NSPoint(x: 0, y: 0)
        let store = Store(withMouseLoc: location, andNekoLoc: location)

        for _ in 0..<9 {
            _ = store.nextTick(location)
        }
        assertGrooming(store)

        let relocated = NSPoint(x: 100, y: 100)
        store.relocate(to: relocated, mouseLocation: relocated)
        _ = store.nextTick(relocated)

        assertIdle(store)
    }

    func testConstrainLeavesOriginInsideAFullyContainingFrame() {
        let visible = NSRect(x: 0, y: 25, width: 1000, height: 750)
        let origin = NSPoint(x: 100, y: 100)
        let result = constrainNekoOrigin(
            proposed: origin,
            current: origin,
            size: NSSize(width: 16, height: 16),
            mouse: NSPoint(x: 500, y: 400),
            visibleFrames: [visible]
        )
        XCTAssertEqual(result, origin)
    }

    func testEmptyVisibleFramesDoNotClamp() {
        let proposed = NSPoint(x: -50, y: -50)
        let result = constrainNekoOrigin(
            proposed: proposed,
            current: .zero,
            size: NSSize(width: 16, height: 16),
            mouse: NSPoint(x: -80, y: -80),
            visibleFrames: []
        )
        XCTAssertEqual(result, proposed)
    }

    func testChaseStopsAtMenuBarAndScratches() {
        let visible = NSRect(x: 0, y: 25, width: 1000, height: 750)
        let origin = NSPoint(x: 100, y: 759)
        let mouse = NSPoint(x: 100, y: 800)
        let store = Store(withMouseLoc: mouse, andNekoLoc: origin)

        let next = store.nextTick(mouse, visibleFrames: [visible])
        XCTAssertEqual(next.x, 100)
        XCTAssertEqual(next.y, 759)
        assertScratching(store)
    }

    func testChaseStopsAtDockAndScratches() {
        let visible = NSRect(x: 0, y: 25, width: 1000, height: 750)
        let origin = NSPoint(x: 100, y: 25)
        let mouse = NSPoint(x: 100, y: 0)
        let store = Store(withMouseLoc: mouse, andNekoLoc: origin)

        let next = store.nextTick(mouse, visibleFrames: [visible])
        XCTAssertEqual(next, origin)
        assertScratching(store)
    }

    func testMouseInsideStopRadiusAtEdgeDoesNotScratch() {
        let visible = NSRect(x: 0, y: 25, width: 1000, height: 750)
        let origin = NSPoint(x: 100, y: 759)
        let mouse = NSPoint(x: 108, y: 759)
        let store = Store(withMouseLoc: mouse, andNekoLoc: origin)

        let next = store.nextTick(mouse, visibleFrames: [visible])
        XCTAssertEqual(next, origin)
        assertIdle(store)
    }

    func testAdjacentDisplayLetsCatEnterMouseFrame() {
        let screenA = NSRect(x: 0, y: 0, width: 200, height: 100)
        let screenB = NSRect(x: 200, y: 0, width: 200, height: 100)
        let size = NSSize(width: 16, height: 16)
        let current = NSPoint(x: 184, y: 40)
        let proposed = NSPoint(x: 200, y: 40)
        let mouse = NSPoint(x: 260, y: 40)

        let result = constrainNekoOrigin(
            proposed: proposed,
            current: current,
            size: size,
            mouse: mouse,
            visibleFrames: [screenA, screenB]
        )
        XCTAssertEqual(result, proposed)
        XCTAssertTrue(screenB.contains(NSRect(origin: result, size: size)))
    }

    func testGapBetweenFramesBlocksAndScratches() {
        let screenA = NSRect(x: 0, y: 0, width: 200, height: 100)
        let screenB = NSRect(x: 250, y: 0, width: 200, height: 100)
        let origin = NSPoint(x: 184, y: 40)
        let mouse = NSPoint(x: 300, y: 40)
        let store = Store(withMouseLoc: mouse, andNekoLoc: origin)

        let next = store.nextTick(mouse, visibleFrames: [screenA, screenB])
        XCTAssertEqual(next, origin)
        XCTAssertFalse(NSRect(x: 200, y: 0, width: 50, height: 100).contains(NSRect(origin: next, size: NSSize(width: 16, height: 16))))
        assertScratching(store)
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

    private func assertGrooming(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 2,
              case .grooming1 = store.anim[0],
              case .grooming2 = store.anim[1] else {
            XCTFail("Expected grooming animation", file: file, line: line)
            return
        }
    }

    private func assertScratching(_ store: Store, file: StaticString = #filePath, line: UInt = #line) {
        guard store.anim.count == 2,
              case .scratching1 = store.anim[0],
              case .scratching2 = store.anim[1] else {
            XCTFail("Expected scratching animation", file: file, line: line)
            return
        }
    }
}
