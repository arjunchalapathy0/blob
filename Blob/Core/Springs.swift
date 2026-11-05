import SwiftUI

/// One motion language. Every transition in Blob is one of these springs.
enum Springs {
    /// Notch opening: a little overshoot so it feels like it inflates.
    static let open = Animation.spring(response: 0.42, dampingFraction: 0.74)
    /// Notch closing: quicker, settles without bounce.
    static let close = Animation.spring(response: 0.34, dampingFraction: 0.9)
    /// Small UI state changes (tabs, toggles, wings).
    static let snap = Animation.spring(response: 0.3, dampingFraction: 0.82)
    /// Soft, slow settle for content.
    static let soft = Animation.spring(response: 0.55, dampingFraction: 0.85)
    /// Playful, for the character and confirmations.
    static let wobble = Animation.spring(response: 0.38, dampingFraction: 0.58)
}
