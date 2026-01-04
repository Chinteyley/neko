import SwiftUI

struct NekoAnimation: View {
    let animation: [NekoState]
    let tick: Int
    let size: CGFloat

    var body: some View {
        Neko(state: currentState, size: size)
    }
    
    private var currentState: NekoState {
        guard !animation.isEmpty else { return .idle }
        return animation[tick % animation.count]
    }
}

struct NekoAnimation_Previews: PreviewProvider {
    static var previews: some View {
        NekoAnimation(
            animation: [.sleeping1, .sleeping2],
            tick: 0,
            size: 32
        )
    }
}
