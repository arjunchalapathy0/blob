import SwiftUI

/// The notch silhouette: flush with the top of the screen, small concave "ears"
/// where it meets the menu bar, and continuous (squircle-like) bottom corners.
/// The frame includes the ears, so the body is `width - 2 * topRadius` wide.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        // Continuous corners start 1.28x the radius away from the corner.
        let k: CGFloat = 1.28
        let tr = max(0, min(topRadius, r.width / 4, r.height / 2))
        let br = max(0, min(bottomRadius, (r.width - 2 * tr) / (2 * k), (r.height - tr) / k))
        let left = r.minX + tr
        let right = r.maxX - tr

        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        // Top-left ear (concave).
        p.addCurve(to: CGPoint(x: left, y: r.minY + tr),
                   control1: CGPoint(x: r.minX + tr * 0.62, y: r.minY),
                   control2: CGPoint(x: left, y: r.minY + tr * 0.38))
        p.addLine(to: CGPoint(x: left, y: r.maxY - br * k))
        // Bottom-left.
        p.addCurve(to: CGPoint(x: left + br * k, y: r.maxY),
                   control1: CGPoint(x: left, y: r.maxY - br * 0.26),
                   control2: CGPoint(x: left + br * 0.26, y: r.maxY))
        p.addLine(to: CGPoint(x: right - br * k, y: r.maxY))
        // Bottom-right.
        p.addCurve(to: CGPoint(x: right, y: r.maxY - br * k),
                   control1: CGPoint(x: right - br * 0.26, y: r.maxY),
                   control2: CGPoint(x: right, y: r.maxY - br * 0.26))
        p.addLine(to: CGPoint(x: right, y: r.minY + tr))
        // Top-right ear.
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY),
                   control1: CGPoint(x: right, y: r.minY + tr * 0.38),
                   control2: CGPoint(x: r.maxX - tr * 0.62, y: r.minY))
        p.closeSubpath()
        return p
    }
}
