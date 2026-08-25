import SwiftUI

struct NekoAnimation: View {
    var animation: [NekoState]
    var tick: Int
    var size: NekoSize

    var body: some View {
        Neko(state: animation[tick % animation.count], size: size)
    }
}

struct NekoAnimation_Previews: PreviewProvider {
    static var previews: some View {
        NekoAnimation(
            animation: [.sleeping1, .sleeping2],
            tick: 0,
            size: .small
        )
    }
}
