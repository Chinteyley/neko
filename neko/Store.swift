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
    private var thinkingTimeRemaining: TimeInterval = 0
    private let thinkingDuration: TimeInterval = 0.6

    @Published var nekoLoc: NSPoint = NSPoint(x: 0, y: 0)
    @Published var mouseLoc: NSPoint = NSPoint(x: 0, y: 0)
    @Published var tick: Int = 0
    @Published var anim: [NekoState] = [.idle]

    init(withMouseLoc mouseLoc: NSPoint, andNekoLoc nekoLoc: NSPoint) {
        self.mouseLoc = mouseLoc
        self.nekoLoc = nekoLoc
        self.direction = nextDirection(
            mouseLoc,
            nekoLoc,
            threshold: Settings.shared.currentFollowDistance.stopMultiplier
        )
    }

    func relocate(to location: NSPoint, mouseLocation: NSPoint) {
        nekoLoc = location
        mouseLoc = mouseLocation
        direction = .none
        tick = 0
        ticksSinceLastMove = 0
        thinkingTimeRemaining = 0
        anim = [.idle]
    }

    func nextTick(_ newMouseLoc: NSPoint) -> NSPoint {
        tick += 1

        let threshold = direction == .none
            ? Settings.shared.currentFollowDistance.resumeMultiplier
            : Settings.shared.currentFollowDistance.stopMultiplier
        let newDirection = nextDirection(newMouseLoc, nekoLoc, threshold: threshold)
        if direction != newDirection {
            let wasIdle = direction == .none
            direction = newDirection
            tick = 0
            ticksSinceLastMove = 0
            thinkingTimeRemaining = 0

            if newDirection == .none {
                if mouseLoc == newMouseLoc {
                    thinkingTimeRemaining = thinkingDuration
                    anim = [.thinking]
                } else {
                    anim = [.idle]
                }
                return nekoLoc
            }

            if wasIdle {
                anim = [.alert]
                return nekoLoc
            }
        }
        if mouseLoc != newMouseLoc {
            thinkingTimeRemaining = 0
        }

        if thinkingTimeRemaining > thinkingDuration.ulp {
            thinkingTimeRemaining -= Settings.shared.currentSpeed.rawValue
            if thinkingTimeRemaining > thinkingDuration.ulp {
                anim = [.thinking]
                return nekoLoc
            }
        }

        if mouseLoc == newMouseLoc {
            ticksSinceLastMove += 1
        }

        switch direction {
        case .none:
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

        if direction != .none {
            nekoLoc = moveToward(newMouseLoc)
        }

        mouseLoc = newMouseLoc
        return nekoLoc
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

private var step: CGFloat { Settings.shared.currentSize.rawValue }

private var stopRadius: CGFloat {
    Settings.shared.currentFollowDistance.stopMultiplier * step
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
