import SwiftUI

struct ContentView: View {
    @ObservedObject var store: Store
    @ObservedObject var settings = Settings.shared

    var body: some View {
        NekoAnimation(
            animation: store.anim,
            tick: store.tick,
            size: settings.currentSize.rawValue
        )
    }
}
