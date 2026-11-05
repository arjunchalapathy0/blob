import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var np: NowPlayingService
    @AppStorage(Prefs.monochromeArtwork) private var monoArt = false

    var body: some View {
        if let track = np.track {
            HStack(spacing: 18) {
                Artwork(image: np.artwork, size: 118, radius: 20, mono: monoArt)
                    .overlay(alignment: .bottomTrailing) {
                        if let icon = np.appIcon {
                            Image(nsImage: icon).resizable().frame(width: 24, height: 24)
                                .offset(x: 6, y: 6)
                                .onTapGesture { np.openPlayer() }
                        }
                    }
                    .scaleEffect(track.isPlaying ? 1 : 0.94)
                    .animation(Springs.wobble, value: track.isPlaying)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(Theme.font(15, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " — "))
                        .font(Theme.font(12)).foregroundStyle(Theme.secondary).lineLimit(1)
                    Spacer(minLength: 8)
                    Scrubber(track: track) { np.seek(to: $0) }
                    HStack(spacing: 30) {
                        IconButton(symbol: "backward.fill", size: 15) { np.previous() }
                        IconButton(symbol: track.isPlaying ? "pause.fill" : "play.fill", size: 22, active: true) {
                            np.togglePlayPause()
                        }
                        .contentTransition(.symbolEffect(.replace))
                        IconButton(symbol: "forward.fill", size: 15) { np.next() }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            EmptyState(text: "Nothing playing", detail: "Play something and it shows up here.", mood: .sleepy)
        }
    }
}

struct Scrubber: View {
    let track: TrackInfo
    let onSeek: (Double) -> Void
    @State private var dragValue: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let elapsed = dragValue ?? track.elapsed(at: ctx.date)
            let duration = max(track.duration, 0.001)
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.fillStrong)
                        Capsule().fill(Theme.ink)
                            .frame(width: geo.size.width * CGFloat(min(1, elapsed / duration)))
                    }
                    .frame(height: dragValue == nil ? 4 : 7)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            dragValue = Double(max(0, min(1, g.location.x / geo.size.width))) * duration
                        }
                        .onEnded { _ in
                            if let v = dragValue { onSeek(v) }
                            dragValue = nil
                        })
                    .animation(Springs.snap, value: dragValue == nil)
                }
                .frame(height: 10)
                HStack {
                    Text(elapsed.clock)
                    Spacer()
                    Text(track.duration > 0 ? "-" + (track.duration - elapsed).clock : "")
                }
                .font(Theme.digits(10)).foregroundStyle(Theme.tertiary)
            }
        }
        .disabled(track.duration <= 0)
    }
}
