import SwiftUI

enum NekoState {
    case idle
    case alert
    case scratching1
    case scratching2
    case grooming1
    case grooming2
    case yawning
    case sleeping1
    case sleeping2
    case movingNorthWest1
    case movingNorthWest2
    case movingNorth1
    case movingNorth2
    case movingNorthEast1
    case movingNorthEast2
    case movingEast1
    case movingEast2
    case movingSouthEast1
    case movingSouthEast2
    case movingSouth1
    case movingSouth2
    case movingSouthWest1
    case movingSouthWest2
    case movingWest1
    case movingWest2
}

struct Neko: View {
    let state: NekoState
    let size: CGFloat
    
    private let spriteColumns = 5
    private let spriteRows = 6

    var body: some View {
        Image("Neko")
            .interpolation(.none)
            .resizable()
            .frame(width: size * CGFloat(spriteColumns), height: size * CGFloat(spriteRows), alignment: .topLeading)
            .offset(x: offset.x, y: offset.y)
            .frame(width: size, height: size, alignment: .topLeading)
            .clipped()
    }

    private func sprite(_ col: Int, _ row: Int) -> CGPoint {
        CGPoint(x: CGFloat(-row) * size, y: CGFloat(-col) * size)
    }

    private var offset: CGPoint {
        switch state {
        case .idle: sprite(0, 4)
        case .alert: sprite(0, 0)
        case .scratching1: sprite(0, 2)
        case .scratching2: sprite(0, 3)
        case .grooming1: sprite(1, 3)
        case .grooming2: sprite(2, 3)
        case .yawning: sprite(1, 4)
        case .sleeping1: sprite(4, 3)
        case .sleeping2: sprite(4, 2)
        case .movingNorthWest1: sprite(1, 5)
        case .movingNorthWest2: sprite(2, 5)
        case .movingNorth1: sprite(4, 4)
        case .movingNorth2: sprite(0, 5)
        case .movingNorthEast1: sprite(3, 5)
        case .movingNorthEast2: sprite(4, 5)
        case .movingEast1: sprite(3, 4)
        case .movingEast2: sprite(2, 4)
        case .movingSouthEast1: sprite(2, 1)
        case .movingSouthEast2: sprite(2, 2)
        case .movingSouth1: sprite(0, 1)
        case .movingSouth2: sprite(1, 0)
        case .movingSouthWest1: sprite(1, 2)
        case .movingSouthWest2: sprite(2, 0)
        case .movingWest1: sprite(3, 1)
        case .movingWest2: sprite(3, 0)
        }
    }
}

struct Neko_Previews: PreviewProvider {
    static var previews: some View {
        Neko(state: .scratching1, size: 32)
    }
}
