import SwiftUI

/// The expanded notch: a header row beside the hardware notch, and the selected module below.
struct OpenView: View {
    @ObservedObject var vm: NotchViewModel
    @EnvironmentObject private var updates: UpdateService
    @EnvironmentObject private var ask: AskService
    @Namespace private var tabNS
    /// The tab under the pointer: its name shows in the title while you look for the right one.
    @State private var hoveredTab: ModuleID?

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: vm.notch.height)
                .padding(.horizontal, 18)
            Group {
                if vm.isWelcoming {
                    WelcomeView { withAnimation(Springs.soft) { vm.finishWelcome() } }
                        .transition(.blurReplace)
                } else {
                    module
                        .id(vm.tab)
                        .transition(.blurReplace)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(Springs.snap, value: vm.tab)
    }

    /// Left of the hardware notch: who and where you are, then the app's own controls.
    /// Right of it: the tabs, and nothing else, so each one gets a comfortable target.
    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                BlobCharacter(mood: vm.mood, look: vm.look, size: 15)
                Text(title)
                    .font(Theme.font(12, .semibold))
                    .foregroundStyle(hoveredTab == nil ? Theme.secondary : Theme.ink)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.12), value: hoveredTab)
                Spacer(minLength: 4)
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: vm.notch.width + 8)

            tabs
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var title: String {
        if vm.isWelcoming { return "Welcome" }
        return (hoveredTab ?? vm.tab).title
    }

    private var controls: some View {
        HStack(spacing: 0) {
            if updates.isAvailable || updates.isUpdating {
                IconButton(symbol: updates.isUpdating ? "arrow.triangle.2.circlepath" : "arrow.down.circle.fill",
                           size: 10, active: true,
                           help: updates.isUpdating ? "Updating…" : "Update Blob") {
                    updates.update()
                }
                .symbolEffect(.pulse, isActive: updates.isUpdating)
                .transition(.scale.combined(with: .opacity))
            }
            IconButton(symbol: vm.isPinned ? "pin.fill" : "pin", size: 10, active: vm.isPinned,
                       help: vm.isPinned ? "Unpin (close when the cursor leaves)" : "Pin open") {
                withAnimation(Springs.wobble) { vm.togglePin() }
            }
            .contentTransition(.symbolEffect(.replace))
            .rotationEffect(.degrees(vm.isPinned ? 0 : 35))
            .animation(Springs.wobble, value: vm.isPinned)
            IconButton(symbol: "gearshape", size: 10, help: "Settings") {
                vm.close()
                SettingsWindow.show()
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 1) {
            ForEach(ModuleID.enabled) { m in
                TabButton(module: m, selected: vm.tab == m && !vm.isWelcoming, namespace: tabNS) { vm.select(m) }
                    .onHover { inside in
                        if inside { hoveredTab = m } else if hoveredTab == m { hoveredTab = nil }
                    }
            }
        }
        .opacity(vm.isWelcoming ? 0.4 : 1)
        .allowsHitTesting(!vm.isWelcoming)
    }

    @ViewBuilder private var module: some View {
        switch vm.tab {
        case .nowPlaying: NowPlayingView()
        case .ask: LockGate(module: .ask) {
            if ask.cliPath != nil { AgentView() } else { AskView(screen: vm.screen) }
        }
        case .shelf: LockGate(module: .shelf) { ShelfView() }
        case .clipboard: LockGate(module: .clipboard) { ClipboardView() }
        case .calendar: CalendarView()
        case .timers: TimersView()
        case .claude: ClaudeView()
        case .tools: QuickToolsView(close: { vm.close() })
        case .stats: StatsView()
        case .camera: CameraView()
        }
    }
}

/// One tab: the selected one is a white capsule with a black icon, so it reads at a glance.
private struct TabButton: View {
    let module: ModuleID
    let selected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: module.symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(selected ? Color.black : (hovering ? Theme.ink : Theme.secondary))
                .frame(maxWidth: 24)
                .frame(height: 22)
                .background {
                    if selected {
                        Capsule().fill(Theme.ink)
                            .matchedGeometryEffect(id: "tab", in: namespace)
                    } else if hovering {
                        Capsule().fill(Theme.fillStrong)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .help(module.title)
        .onHover { hovering = $0 }
        .accessibilityLabel(module.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
