import SwiftUI

/// The closed and peeking notch: optional wings on either side of the hardware notch,
/// and the character dropping into view while peeking.
struct ClosedView: View {
    @ObservedObject var vm: NotchViewModel

    var body: some View {
        let wing = vm.activity.wingWidth
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                WingView(activity: vm.activity, side: .leading, mood: vm.mood)
                    .frame(width: wing, alignment: .leading)
                Color.clear.frame(width: vm.notch.width)
                WingView(activity: vm.activity, side: .trailing, mood: vm.mood)
                    .frame(width: wing, alignment: .trailing)
            }
            .frame(height: vm.notch.height)
            .id(vm.activity.category)
            .transition(.blurReplace)

            if vm.phase == .peek {
                BlobCharacter(mood: vm.mood, look: vm.look, size: 16)
                    .padding(.top, 1)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { vm.open() }
    }
}

/// One side of a live activity.
struct WingView: View {
    enum Side { case leading, trailing }
    let activity: LiveActivity
    let side: Side
    let mood: Mood

    @EnvironmentObject private var nowPlaying: NowPlayingService
    @EnvironmentObject private var timers: TimerService
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var calendar: CalendarService
    @AppStorage(Prefs.monochromeArtwork) private var monoArt = false

    var body: some View {
        content
            .font(Theme.font(12, .semibold))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .padding(side == .leading ? .leading : .trailing, 10)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var content: some View {
        switch (activity, side) {
        case (.none, _):
            EmptyView()

        case (.music, .leading):
            Artwork(image: nowPlaying.artwork, size: 20, radius: 6, mono: monoArt)
        case (.music, .trailing):
            Equalizer(playing: nowPlaying.isPlaying)

        case (.notice(let n), .leading):
            Image(systemName: Self.symbol(for: n.kind)).font(.system(size: 12, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
        case (.notice(let n), .trailing):
            noticeTrailing(n.kind)

        case (.timer, .leading):
            Image(systemName: "timer").font(.system(size: 12, weight: .semibold))
        case (.timer, .trailing):
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text((timers.primary?.remaining(at: ctx.date) ?? 0).clock).font(Theme.digits(12, .semibold))
            }

        case (.timerDone, .leading):
            BlobCharacter(mood: .alarmed, size: 13)
        case (.timerDone, .trailing):
            Text("Time’s up")

        case (.claude, .leading):
            BlobCharacter(mood: mood, size: 13)
        case (.claude(let state), .trailing):
            Text(state == .waiting ? "Needs you" : "Working")
                .foregroundStyle(state == .waiting ? Theme.ink : Theme.secondary)

        case (.event, .leading):
            Image(systemName: "calendar").font(.system(size: 12, weight: .semibold))
        case (.event, .trailing):
            TimelineView(.periodic(from: .now, by: 15)) { ctx in
                Text(calendar.imminentLabel(at: ctx.date))
            }
        }
    }

    @ViewBuilder private func noticeTrailing(_ kind: Notice.Kind) -> some View {
        switch kind {
        case .volume(let v, let muted):
            LevelBar(value: muted ? 0 : Double(v), height: 4).frame(width: 44)
        case .brightness(let v):
            LevelBar(value: Double(v), height: 4).frame(width: 44)
        case .message(_, let text):
            Text(text).font(Theme.font(11, .semibold)).minimumScaleFactor(0.8)
        }
    }

    static func symbol(for kind: Notice.Kind) -> String {
        switch kind {
        case .volume(let v, let muted):
            if muted || v <= 0 { return "speaker.slash.fill" }
            return v < 0.34 ? "speaker.wave.1.fill" : v < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        case .brightness(let v): return v < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .message(let symbol, _): return symbol
        }
    }
}

/// Four bars that dance while music plays.
struct Equalizer: View {
    var playing: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !playing)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let d = Double(i)
                    let h = playing ? 4 + 9 * abs(sin(t * (2.1 + d * 0.63) + d * 1.7)) : 3
                    Capsule().fill(Theme.ink).frame(width: 2.5, height: h)
                }
            }
            .frame(height: 14)
        }
    }
}

/// Album art with a monochrome fallback.
struct Artwork: View {
    var image: NSImage?
    var size: CGFloat
    var radius: CGFloat
    var mono = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.fillStrong)
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .saturation(mono ? 0 : 1)
            } else {
                Image(systemName: "music.note").font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
