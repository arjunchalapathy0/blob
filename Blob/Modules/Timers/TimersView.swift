import SwiftUI

struct TimersView: View {
    @EnvironmentObject private var timers: TimerService
    private let presets: [Double] = [1, 3, 5, 10, 25, 45, 60]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                if let ringing = timers.ringing {
                    HStack(spacing: 10) {
                        BlobCharacter(mood: .alarmed, size: 20)
                        Text("\(ringing.label) is done").font(Theme.font(13, .semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        PillButton(title: "Dismiss", prominent: true) { timers.dismissRinging() }
                    }
                    .padding(10)
                    .background(Theme.fillStrong, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(presets, id: \.self) { m in
                            PillButton(title: m < 60 ? "\(Int(m))m" : "1h") { timers.add(minutes: m) }
                        }
                    }
                }

                if timers.timers.isEmpty && timers.ringing == nil {
                    Text("Pick a duration to start a timer.")
                        .font(Theme.font(11)).foregroundStyle(Theme.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(timers.timers) { TimerRow(timer: $0) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(Springs.snap, value: timers.timers)
            .animation(Springs.wobble, value: timers.ringing)

            StopwatchCard()
                .frame(width: 170)
        }
    }
}

private struct TimerRow: View {
    let timer: BlobTimer
    @EnvironmentObject private var timers: TimerService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Theme.fillStrong, lineWidth: 3)
                    Circle().trim(from: 0, to: 1 - timer.progress(at: ctx.date))
                        .stroke(Theme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 20, height: 20)
                Text(timer.label).font(Theme.font(12, .semibold)).foregroundStyle(Theme.secondary)
                Spacer()
                Text(timer.remaining(at: ctx.date).clock)
                    .font(Theme.digits(15, .semibold))
                    .foregroundStyle(timer.isPaused ? Theme.tertiary : Theme.ink)
                IconButton(symbol: timer.isPaused ? "play.fill" : "pause.fill", size: 10) { timers.togglePause(timer) }
                IconButton(symbol: "xmark", size: 10) { timers.cancel(timer) }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct StopwatchCard: View {
    @EnvironmentObject private var timers: TimerService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Stopwatch")
            TimelineView(.animation(minimumInterval: 0.05, paused: !timers.isStopwatchRunning)) { ctx in
                let t = timers.stopwatchElapsed(at: ctx.date)
                Text(t.clock + String(format: ".%01d", Int((t * 10).truncatingRemainder(dividingBy: 10))))
                    .font(Theme.digits(24, .semibold)).foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                PillButton(title: timers.isStopwatchRunning ? "Stop" : "Start", prominent: true) { timers.toggleStopwatch() }
                PillButton(title: "Reset") { timers.resetStopwatch() }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
