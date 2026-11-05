import Foundation
import CoreGraphics

/// How Blob feels. Moods never change the drawing, only how it moves.
enum Mood: String, Equatable {
    case idle, curious, happy, busy, alarmed, sleepy
}

/// A frame of the character's body language.
struct Pose {
    var sx: CGFloat = 1        // horizontal scale
    var sy: CGFloat = 1        // vertical scale (squash/stretch, anchored at the bottom)
    var dx: CGFloat = 0        // offset in units of character size
    var dy: CGFloat = 0
    var rot: CGFloat = 0       // degrees
    var eyeOpen: CGFloat = 1   // 0 closed ... 1 open
    var eyeScale: CGFloat = 1
    var eyeShift: CGFloat = 0  // autonomous horizontal glance, -1 ... 1
    var lookGain: CGFloat = 1  // how much the eyes follow the cursor
    var z: CGFloat = 0         // sleepy "z" opacity

    static func lerp(_ a: Pose, _ b: Pose, _ t: CGFloat) -> Pose {
        func m(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        return Pose(sx: m(a.sx, b.sx), sy: m(a.sy, b.sy), dx: m(a.dx, b.dx), dy: m(a.dy, b.dy),
                    rot: m(a.rot, b.rot), eyeOpen: m(a.eyeOpen, b.eyeOpen), eyeScale: m(a.eyeScale, b.eyeScale),
                    eyeShift: m(a.eyeShift, b.eyeShift), lookGain: m(a.lookGain, b.lookGain), z: m(a.z, b.z))
    }
}

extension Mood {
    /// Procedural motion for this mood at time `t` (seconds).
    func pose(at t: Double) -> Pose {
        let tau = 2 * Double.pi
        func s(_ period: Double, _ phase: Double = 0) -> CGFloat { CGFloat(sin(tau * t / period + phase)) }
        func fract(_ x: Double) -> Double { x - floor(x) }

        var p = Pose()
        switch self {
        case .idle:
            let b = s(3.6)
            p.sy = 1 + 0.028 * b
            p.sx = 1 - 0.018 * b
            p.eyeShift = 0.25 * s(9.0)
            p.eyeOpen = Mood.blink(t)

        case .curious:
            let b = s(2.8)
            p.sy = 1.04 + 0.02 * b
            p.sx = 0.98
            p.dy = -0.04
            p.rot = 5 + 2 * s(4.2)
            p.eyeScale = 1.18
            p.lookGain = 1.4
            p.eyeOpen = Mood.blink(t + 1.3)

        case .happy:
            // Hops at about 2 Hz, squashing on each landing.
            let phase = fract(t * 2.0)
            let air = CGFloat(sin(Double.pi * phase))       // 0 on the ground, 1 at the top
            let land = pow(1 - air, 6)
            p.dy = -0.16 * air
            p.sy = 1 - 0.1 * land + 0.04 * air
            p.sx = 1 + 0.08 * land - 0.02 * air
            p.rot = 3 * s(1.0)
            p.eyeOpen = 0.5                                 // content squint
            p.lookGain = 0.6

        case .busy:
            p.rot = 4 * s(0.42)
            p.sx = 1 + 0.03 * s(0.21)
            p.sy = 1 - 0.03 * s(0.21)
            p.eyeShift = s(1.4)                            // reading left to right
            p.eyeOpen = 0.78 * Mood.blink(t + 0.7)
            p.lookGain = 0.2

        case .alarmed:
            // A jump every 1.2 s with a decaying shake.
            let e = CGFloat(exp(-3.2 * fract(t / 1.2)))
            p.dy = -0.22 * e
            p.sy = 1 + 0.12 * e
            p.sx = 1 - 0.06 * e
            p.dx = 0.05 * e * s(0.09)
            p.rot = 8 * e * s(0.16)
            p.eyeScale = 1.35
            p.lookGain = 0.3

        case .sleepy:
            let b = s(5.2)
            p.sy = 0.9 + 0.035 * b
            p.sx = 1.06 - 0.02 * b
            p.dy = 0.04
            p.rot = -5
            p.eyeOpen = 0.1
            p.lookGain = 0
            p.z = 1
        }
        return p
    }

    /// 1 when open; dips to 0 for about 120 ms every few seconds, double blink every third.
    static func blink(_ t: Double) -> CGFloat {
        let period = 4.6
        let cycle = Int(floor(t / period))
        let local = t - Double(cycle) * period
        func dip(_ x: Double) -> CGFloat {
            guard x >= 0, x < 0.14 else { return 1 }
            return CGFloat(abs(cos(Double.pi * x / 0.14)))
        }
        let first = dip(local)
        let second = cycle % 3 == 0 ? dip(local - 0.22) : 1
        return min(first, second)
    }
}
