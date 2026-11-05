import SwiftUI

/// A still frame of the Blob character, for places that can't animate (the Dynamic Island).
/// Each mood gets a recognizable pose.
struct BlobFace: View {
    var mood: Mood
    var size: CGFloat = 16

    var body: some View {
        let p = pose
        RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
            .fill(Color(white: 0.58))
            .frame(width: size * 1.12, height: size)
            .overlay {
                HStack(spacing: size * 0.24) {
                    Capsule().frame(width: size * 0.13 * p.eyeScale, height: max(size * 0.04, size * 0.2 * p.eyeScale * p.eyeOpen))
                    Capsule().frame(width: size * 0.13 * p.eyeScale, height: max(size * 0.04, size * 0.2 * p.eyeScale * p.eyeOpen))
                }
                .foregroundStyle(Color.black)
                .offset(x: p.eyeShift * size * 0.1, y: -size * 0.05)
            }
            .scaleEffect(x: p.sx, y: p.sy, anchor: .bottom)
            .rotationEffect(.degrees(p.rot), anchor: .bottom)
            .frame(width: size * 1.3, height: size * 1.2, alignment: .bottom)
    }

    private var pose: (sx: CGFloat, sy: CGFloat, rot: Double, eyeOpen: CGFloat, eyeScale: CGFloat, eyeShift: CGFloat) {
        switch mood {
        case .idle: (1, 1, 0, 1, 1, 0)
        case .curious: (0.98, 1.04, 5, 1, 1.18, 0.3)
        case .happy: (1.06, 0.92, -3, 0.5, 1, 0)
        case .busy: (1.02, 0.98, 4, 0.78, 1, 0.7)
        case .alarmed: (0.94, 1.1, 0, 1, 1.35, 0)
        case .sleepy: (1.06, 0.9, -5, 0.1, 1, 0)
        }
    }
}
