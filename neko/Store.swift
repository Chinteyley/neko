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
    private var direction: Direction = .none
    private var previousDirection: Direction = .none
    private var ticksSinceLastMove = 0
    private var isScratching = false
    private var scratchTicks = 0

    @Published var nekoLoc: NSPoint
    @Published var mouseLoc: NSPoint
    @Published var tick: Int = 0
    @Published var anim: [NekoState] = [.idle]

    private var step: CGFloat {
        Settings.shared.currentSize.rawValue
    }
    
    private var idleAnimationsEnabled: Bool {
        Settings.shared.idleAnimationsEnabled
    }

    init(withMouseLoc mouseLoc: NSPoint, andNekoLoc nekoLoc: NSPoint) {
        self.mouseLoc = mouseLoc
        self.nekoLoc = nekoLoc
    }

    func nextTick(_ newMouseLoc: NSPoint) -> NSPoint {
        tick += 1

        let newDirection = nextDirection(newMouseLoc, nekoLoc)
        
        if isScratching {
            scratchTicks += 1
            anim = [.scratching1, .scratching2]
            if scratchTicks > 8 {
                isScratching = false
                scratchTicks = 0
            }
            mouseLoc = newMouseLoc
            return nekoLoc
        }
        
        if direction != newDirection {
            tick = 0
            
            if previousDirection != .none && newDirection == .none {
                isScratching = true
                scratchTicks = 0
                anim = [.scratching1, .scratching2]
            } else if direction == .none && newDirection != .none {
                anim = [.alert]
            } else {
                anim = [.idle]
            }
            
            previousDirection = direction
            direction = newDirection
            ticksSinceLastMove = 0
            mouseLoc = newMouseLoc
            return nekoLoc
        }

        let mouseMovedSignificantly = abs(mouseLoc.x - newMouseLoc.x) > 1 || abs(mouseLoc.y - newMouseLoc.y) > 1
        if !mouseMovedSignificantly {
            ticksSinceLastMove += 1
        } else {
            ticksSinceLastMove = 0
        }

        switch direction {
        case .none:
            if idleAnimationsEnabled {
                if ticksSinceLastMove > 50 {
                    anim = [.sleeping1, .sleeping1, .sleeping1, .sleeping1, .sleeping2, .sleeping2, .sleeping2, .sleeping2]
                } else if ticksSinceLastMove > 45 {
                    anim = [.yawning, .yawning]
                } else if ticksSinceLastMove > 25 {
                    anim = [.idle]
                } else if ticksSinceLastMove > 12 {
                    anim = [.grooming1, .grooming2]
                } else {
                    anim = [.idle]
                }
            } else {
                anim = [.idle]
            }
        case .northWest:
            anim = [.movingNorthWest1, .movingNorthWest2]
            nekoLoc = move(-1, 1)
        case .north:
            anim = [.movingNorth1, .movingNorth2]
            nekoLoc = move(0, 1)
        case .northEast:
            anim = [.movingNorthEast1, .movingNorthEast2]
            nekoLoc = move(1, 1)
        case .east:
            anim = [.movingEast1, .movingEast2]
            nekoLoc = move(1, 0)
        case .southEast:
            anim = [.movingSouthEast1, .movingSouthEast2]
            nekoLoc = move(1, -1)
        case .south:
            anim = [.movingSouth1, .movingSouth2]
            nekoLoc = move(0, -1)
        case .southWest:
            anim = [.movingSouthWest1, .movingSouthWest2]
            nekoLoc = move(-1, -1)
        case .west:
            anim = [.movingWest1, .movingWest2]
            nekoLoc = move(-1, 0)
        }

        mouseLoc = newMouseLoc
        return nekoLoc
    }

    private func move(_ xSteps: CGFloat, _ ySteps: CGFloat) -> NSPoint {
        NSPoint(x: nekoLoc.x + step * xSteps, y: nekoLoc.y + step * ySteps)
    }

    private func nextDirection(_ mouseLoc: NSPoint, _ nekoLoc: NSPoint) -> Direction {
        let d = delta(nekoLoc, mouseLoc)
        if d.x >= 1 {
            if d.y > -1 && d.y < 1 {
                return .west
            } else if d.y >= 1 {
                return .southWest
            } else {
                return .northWest
            }
        } else if d.x <= -1 {
            if d.y > -1 && d.y < 1 {
                return .east
            } else if d.y >= 1 {
                return .southEast
            } else {
                return .northEast
            }
        } else {
            if d.y > -1 && d.y < 1 {
                return .none
            } else if d.y >= 1 {
                return .south
            } else {
                return .north
            }
        }
    }

    private func delta(_ p1: NSPoint, _ p2: NSPoint) -> NSPoint {
        NSPoint(x: (p1.x - p2.x) / step, y: (p1.y - p2.y) / step)
    }
}
