import SwiftUI

/// Blob: a grey rounded rectangle with two eyes. It shows emotion only through motion.
struct BlobCharacter: View {
    var mood: Mood
    var look: CGSize = .zero
    var size: CGFloat = 20

    @State private var previous: Mood = .idle
    @State private var changedAt: Date = .distantPast

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let k = Self.springProgress(ctx.date.timeIntervalSince(changedAt))
            let pose = Pose.lerp(previous.pose(at: t), mood.pose(at: t), k)
            figure(pose, t: t)
        }
        .frame(width: size * 1.3, height: size * 1.2)
        .onChange(of: mood) { old, _ in
            previous = old
            changedAt = Date()
        }
        .accessibilityLabel("Blob is \(mood.rawValue)")
    }

    private func figure(_ p: Pose, t: Double) -> some View {
        let w = size * 1.12
        let h = size
        let lookX = max(-1, min(1, look.width)) * p.lookGain + p.eyeShift
        let lookY = max(-1, min(1, look.height)) * p.lookGain
        let eyeW = size * 0.13 * p.eyeScale
        let eyeH = max(size * 0.035, size * 0.2 * p.eyeScale * p.eyeOpen)

        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                .fill(Theme.blob)
                .frame(width: w, height: h)
                .overlay {
                    HStack(spacing: size * 0.24) {
                        Capsule().frame(width: eyeW, height: eyeH)
                        Capsule().frame(width: eyeW, height: eyeH)
                    }
                    .foregroundStyle(Theme.blobEye)
                    .offset(x: lookX * size * 0.1, y: -size * 0.05 + lookY * size * 0.07)
                }
                .scaleEffect(x: p.sx, y: p.sy, anchor: .bottom)
                .rotationEffect(.degrees(Double(p.rot + look.width * 3 * p.lookGain)), anchor: .bottom)
                .offset(x: p.dx * size, y: p.dy * size)

            if p.z > 0.01 {
                let f = CGFloat(t.truncatingRemainder(dividingBy: 2.4) / 2.4)
                Text("z")
                    .font(Theme.font(size * 0.42, .bold))
                    .foregroundStyle(Theme.secondary)
                    .offset(x: size * (0.5 + 0.15 * f), y: -size * (0.55 + 0.4 * f))
                    .opacity(Double(p.z * (1 - f)))
            }
        }
        .frame(width: size * 1.3, height: size * 1.2, alignment: .bottom)
    }

    /// Damped spring from 0 to 1 with a small overshoot, used to blend between moods.
    static func springProgress(_ dt: TimeInterval) -> CGFloat {
        guard dt > 0 else { return 0 }
        guard dt < 1.4 else { return 1 }
        return CGFloat(1 - exp(-6.5 * dt) * cos(9.5 * dt))
    }
}
