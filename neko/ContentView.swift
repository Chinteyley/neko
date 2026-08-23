import SwiftUI

struct ContentView: View {
    @ObservedObject var store: Store
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        let size = settings.currentSize
        let window = NekoSignMetrics.windowSize(for: size)

        VStack(alignment: .leading, spacing: 0) {
            NekoSignBubble(text: settings.currentSign.text)
                .contentShape(Rectangle())
                .onTapGesture { settings.cycleSign() }

            Color.black
                .frame(width: 1, height: NekoSignMetrics.stickHeight)
                .padding(.leading, max(0, size.rawValue / 2 - 0.5))

            NekoAnimation(
                animation: $store.anim,
                tick: $store.tick,
                size: size
            )
            .contentShape(Rectangle())
            .onTapGesture { settings.cycleSign() }
        }
        .frame(width: window.width, height: window.height, alignment: .bottomLeading)
        .background(Color.clear)
        .ignoresSafeArea()
    }
}

struct NekoSignBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 6)
            .frame(
                width: NekoSignMetrics.bubbleWidth,
                height: NekoSignMetrics.bubbleHeight,
                alignment: .leading
            )
            .background(Color.white.opacity(0.95))
            .overlay(
                Rectangle()
                    .strokeBorder(Color.black, lineWidth: 1)
            )
    }
}
