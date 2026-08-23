import Foundation

enum Direction {
    case none
    case northWest
    case north
    case northEast
    case east
    case southEast
    case south
    case southWest
    case west
}

final class Store: ObservableObject {
    private var direction: Direction
    private var ticksSinceLastMove = 0
    private var thinkingDeadline: Date?
    private let thinkingDuration: TimeInterval = 0.6
    private let now: () -> Date

    @Published var nekoLoc: NSPoint = NSPoint(x: 0, y: 0)
    @Published var mouseLoc: NSPoint = NSPoint(x: 0, y: 0)
    @Published var tick: Int = 0
    @Published var anim: [NekoState] = [.idle]

    init(
        withMouseLoc mouseLoc: NSPoint,
        andNekoLoc nekoLoc: NSPoint,
        now: @escaping () -> Date = Date.init
    ) {
        self.mouseLoc = mouseLoc
        self.nekoLoc = nekoLoc
        self.now = now
        self.direction = nextDirection(
            mouseLoc,
            nekoLoc,
            threshold: stopMultiplier
        )
    }

    func relocate(to location: NSPoint, mouseLocation: NSPoint) {
        nekoLoc = location
        mouseLoc = mouseLocation
        direction = .none
        tick = 0
        ticksSinceLastMove = 0
        thinkingDeadline = nil
        anim = [.idle]
    }

    func nextTick(_ newMouseLoc: NSPoint, visibleFrames: [NSRect] = [], windowSize: NSSize? = nil) -> NSPoint {
        tick += 1

        let still = !mouseMoved(from: mouseLoc, to: newMouseLoc)
        let threshold = direction == .none ? resumeMultiplier : stopMultiplier
        var newDirection = nextDirection(newMouseLoc, nekoLoc, threshold: threshold)
        if shouldArrive(at: newMouseLoc) {
            newDirection = .none
        }

        if direction != newDirection {
            let wasIdle = direction == .none
            direction = newDirection
            tick = 0
            ticksSinceLastMove = 0
            thinkingDeadline = nil

            if newDirection == .none {
                arrive(still: still)
                return nekoLoc
            }

            if wasIdle {
                anim = [.alert]
                return nekoLoc
            }
        }
        if !still {
            thinkingDeadline = nil
        }

        if let thinkingDeadline {
            if now() < thinkingDeadline {
                anim = [.thinking]
                return nekoLoc
            }
            self.thinkingDeadline = nil
        }

        if still {
            ticksSinceLastMove += 1
        }

        if direction == .none {
            setIdleAnimation()
            mouseLoc = newMouseLoc
            return nekoLoc
        }

        let unconstrained = moveToward(newMouseLoc)
        let footprint = windowSize ?? NSSize(width: step, height: step)
        let constrained = constrainNekoOrigin(
            proposed: unconstrained,
            current: nekoLoc,
            size: footprint,
            mouse: newMouseLoc,
            visibleFrames: visibleFrames
        )
        let blocked = unconstrained != nekoLoc && constrained == nekoLoc

        if blocked {
            anim = [.scratching1, .scratching2]
            mouseLoc = newMouseLoc
            return nekoLoc
        }

        if constrained == nekoLoc {
            arrive(still: still)
            mouseLoc = newMouseLoc
            return nekoLoc
        }

        setWalkAnimation()
        nekoLoc = constrained
        mouseLoc = newMouseLoc
        return nekoLoc
    }

    private func shouldArrive(at mouse: NSPoint) -> Bool {
        let sprite = NSRect(origin: nekoLoc, size: NSSize(width: step, height: step))
            .insetBy(dx: -0.5, dy: -0.5)
        if sprite.contains(mouse) {
            return true
        }
        let distance = hypot(mouse.x - nekoLoc.x, mouse.y - nekoLoc.y)
        return distance - stopRadius < 1
    }

    private func arrive(still: Bool) {
        direction = .none
        if still {
            thinkingDeadline = now().addingTimeInterval(thinkingDuration)
            anim = [.thinking]
        } else {
            anim = [.idle]
        }
    }

    private func setIdleAnimation() {
        anim = [.idle]

        if ticksSinceLastMove > 33 {
            anim = [.sleeping1, .sleeping1, .sleeping1, .sleeping1, .sleeping2, .sleeping2, .sleeping2, .sleeping2]
        } else if ticksSinceLastMove > 31 {
            anim = [.yawning, .yawning]
        } else if ticksSinceLastMove > 16 {
            anim = [.idle]
        } else if ticksSinceLastMove > 8 {
            anim = [.grooming1, .grooming2]
        }
    }

    private func setWalkAnimation() {
        switch direction {
        case .none:
            break
        case .northWest:
            anim = [.movingNorthWest1, .movingNorthWest2]
        case .north:
            anim = [.movingNorth1, .movingNorth2]
        case .northEast:
            anim = [.movingNorthEast1, .movingNorthEast2]
        case .east:
            anim = [.movingEast1, .movingEast2]
        case .southEast:
            anim = [.movingSouthEast1, .movingSouthEast2]
        case .south:
            anim = [.movingSouth1, .movingSouth2]
        case .southWest:
            anim = [.movingSouthWest1, .movingSouthWest2]
        case .west:
            anim = [.movingWest1, .movingWest2]
        }
    }

    private func moveToward(_ target: NSPoint) -> NSPoint {
        let xDistance = target.x - nekoLoc.x
        let yDistance = target.y - nekoLoc.y
        let distance = sqrt(xDistance * xDistance + yDistance * yDistance)
        let travel = min(step, max(0, distance - stopRadius))

        guard travel > 0 else { return nekoLoc }

        return NSPoint(
            x: nekoLoc.x + xDistance / distance * travel,
            y: nekoLoc.y + yDistance / distance * travel
        )
    }
}

private let stopMultiplier: CGFloat = 1
private let resumeMultiplier: CGFloat = 1.5

private var step: CGFloat { Settings.shared.currentSize.rawValue }

private var stopRadius: CGFloat { stopMultiplier * step }

private func mouseMoved(from: NSPoint, to: NSPoint) -> Bool {
    hypot(to.x - from.x, to.y - from.y) >= 1
}

private func nextDirection(_ mouseLoc: NSPoint, _ nekoLoc: NSPoint, threshold: CGFloat) -> Direction {
    let d = delta(nekoLoc, mouseLoc)
    let horizontal = abs(d.x)
    let vertical = abs(d.y)
    let distance = sqrt(d.x * d.x + d.y * d.y)
    let diagonalThreshold: CGFloat = 0.4142

    if distance <= threshold {
        return .none
    }

    if horizontal > 0 && vertical > 0 &&
        vertical >= horizontal * diagonalThreshold &&
        horizontal >= vertical * diagonalThreshold {
        if d.x >= 0 {
            return d.y >= 0 ? .southWest : .northWest
        }
        return d.y >= 0 ? .southEast : .northEast
    }

    if horizontal >= vertical {
        return d.x >= 0 ? .west : .east
    }

    return d.y >= 0 ? .south : .north
}

private func delta(_ p1: NSPoint, _ p2: NSPoint) -> NSPoint {
    return NSPoint(x: (p1.x - p2.x) / step, y: (p1.y - p2.y) / step)
}
