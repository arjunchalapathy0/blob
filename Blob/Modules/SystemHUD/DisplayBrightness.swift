import CoreGraphics
import Foundation

/// Built-in display brightness through the private DisplayServices framework.
enum DisplayBrightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getFn: GetFn? = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }
        .map { unsafeBitCast($0, to: GetFn.self) }
    private static let setFn: SetFn? = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }
        .map { unsafeBitCast($0, to: SetFn.self) }

    static var builtInDisplay: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static var isAvailable: Bool { getFn != nil && setFn != nil && builtInDisplay != nil }

    static func get() -> Float? {
        guard let getFn, let display = builtInDisplay else { return nil }
        var value: Float = 0
        return getFn(display, &value) == 0 ? value : nil
    }

    @discardableResult
    static func set(_ value: Float) -> Bool {
        guard let setFn, let display = builtInDisplay else { return false }
        return setFn(display, max(0, min(1, value))) == 0
    }
}
