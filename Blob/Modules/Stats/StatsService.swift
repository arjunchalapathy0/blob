import Foundation
import Combine

@MainActor
final class StatsService: ObservableObject {
    @Published private(set) var cpu: [Double] = []
    @Published private(set) var memory: (used: UInt64, total: UInt64) = (0, 0)
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var down: [Double] = []
    @Published private(set) var up: [Double] = []
    @Published private(set) var battery: SystemStats.Battery?

    private let sampler = SystemStats()
    private let notices: NoticeCenter
    private var fast: AnyCancellable?
    private var bag = Set<AnyCancellable>()
    private let historyLength = 40

    init(notices: NoticeCenter) { self.notices = notices }

    func start() {
        battery = sampler.battery()
        // Battery is checked all the time for the charging notice. Everything else only
        // runs while the Stats tab is visible.
        Timer.publish(every: 5, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.sampleBattery() }
            .store(in: &bag)
    }

    func setVisible(_ visible: Bool) {
        if visible, fast == nil {
            sample()
            fast = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
                .sink { [weak self] _ in self?.sample() }
        } else if !visible {
            fast = nil
        }
    }

    private func sample() {
        append(&cpu, sampler.cpu())
        memory = sampler.memory()
        append(&memoryHistory, memory.total > 0 ? Double(memory.used) / Double(memory.total) : 0)
        let net = sampler.network()
        append(&down, net.down)
        append(&up, net.up)
    }

    private func append(_ array: inout [Double], _ value: Double) {
        array.append(value)
        if array.count > historyLength { array.removeFirst(array.count - historyLength) }
    }

    private func sampleBattery() {
        let new = sampler.battery()
        defer { if new != battery { battery = new } }
        guard let new, let old = battery, Prefs.bool(Prefs.chargingNotice) else { return }
        if new.onAC && !old.onAC {
            notices.message("bolt.fill", "\(Int(new.level * 100))%", duration: 2.5)
        } else if !new.onAC && old.onAC {
            notices.message("battery.75percent", "On battery", duration: 2)
        }
    }
}
