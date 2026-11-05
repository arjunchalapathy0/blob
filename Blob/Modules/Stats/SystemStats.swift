import Foundation
import Darwin
import IOKit.ps

/// Cheap system samplers. CPU and network are deltas between calls.
final class SystemStats {
    private var previousCPU: (busy: UInt64, total: UInt64)?
    private var previousNet: (rx: UInt64, tx: UInt64, at: Date)?

    /// Overall CPU use, 0...1.
    func cpu() -> Double {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        var busy: UInt64 = 0, total: UInt64 = 0
        let states = 4 // user, system, idle, nice
        for cpu in 0..<Int(count) {
            let user = UInt64(UInt32(bitPattern: info[cpu * states + 0]))
            let system = UInt64(UInt32(bitPattern: info[cpu * states + 1]))
            let idle = UInt64(UInt32(bitPattern: info[cpu * states + 2]))
            let nice = UInt64(UInt32(bitPattern: info[cpu * states + 3]))
            busy += user + system + nice
            total += user + system + nice + idle
        }
        defer { previousCPU = (busy, total) }
        guard let prev = previousCPU, total > prev.total else { return 0 }
        return Double(busy &- prev.busy) / Double(total - prev.total)
    }

    /// Used and total memory in bytes, counted like Activity Monitor (app + wired + compressed).
    func memory() -> (used: UInt64, total: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else { return (0, total) }
        let page = UInt64(vm_kernel_page_size)
        let app = UInt64(stats.internal_page_count) &- UInt64(stats.purgeable_count)
        let used = (app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        return (min(used, total), total)
    }

    /// Download and upload in bytes per second across Wi-Fi and Ethernet.
    func network() -> (down: Double, up: Double) {
        var rx: UInt64 = 0, tx: UInt64 = 0
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return (0, 0) }
        defer { freeifaddrs(addrs) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            let name = String(cString: ifa.pointee.ifa_name)
            if let addr = ifa.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
               name.hasPrefix("en"), let data = ifa.pointee.ifa_data {
                let d = data.assumingMemoryBound(to: if_data.self).pointee
                rx += UInt64(d.ifi_ibytes)
                tx += UInt64(d.ifi_obytes)
            }
            cursor = ifa.pointee.ifa_next
        }
        let now = Date()
        defer { previousNet = (rx, tx, now) }
        guard let prev = previousNet, rx >= prev.rx, tx >= prev.tx else { return (0, 0) }
        let dt = max(now.timeIntervalSince(prev.at), 0.001)
        return (Double(rx - prev.rx) / dt, Double(tx - prev.tx) / dt)
    }

    struct Battery: Equatable {
        var level: Double
        var isCharging: Bool
        var onAC: Bool
    }

    func battery() -> Battery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            return Battery(level: Double(current) / Double(Swift.max(max, 1)),
                           isCharging: desc[kIOPSIsChargingKey] as? Bool ?? false,
                           onAC: desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
        }
        return nil
    }
}

extension Double {
    /// 1.2 MB/s
    var byteRate: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file) + "/s"
    }
}
