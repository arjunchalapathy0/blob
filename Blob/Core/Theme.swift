import SwiftUI

/// Blob is monochrome: black surface, white ink at a few opacities, one grey for the character.
enum Theme {
    static let surface = Color.black
    static let ink = Color.white
    static let secondary = Color.white.opacity(0.64)
    static let tertiary = Color.white.opacity(0.42)
    static let hairline = Color.white.opacity(0.12)
    static let fill = Color.white.opacity(0.08)
    static let fillStrong = Color.white.opacity(0.16)
    static let blob = Color(white: 0.58)
    static let blobEye = Color.black

    static func font(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func digits(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}
