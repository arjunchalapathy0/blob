import SwiftUI

/// The expanded notch: a header row beside the hardware notch, and the selected module below.
struct OpenView: View {
    @ObservedObject var vm: NotchViewModel
    @Namespace private var tabNS

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: vm.notch.height)
                .padding(.horizontal, 18)
            module
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(vm.tab)
                .transition(.blurReplace)
        }
        .animation(Springs.snap, value: vm.tab)
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                BlobCharacter(mood: vm.mood, look: vm.look, size: 15)
                Text(vm.tab.title)
                    .font(Theme.font(12, .semibold))
                    .foregroundStyle(Theme.secondary)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: vm.notch.width + 8)

            HStack(spacing: 2) {
                ForEach(ModuleID.enabled) { m in
                    Button { vm.select(m) } label: {
                        Image(systemName: m.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(vm.tab == m ? Theme.ink : Theme.tertiary)
                            .frame(width: 20, height: 20)
                            .background {
                                if vm.tab == m {
                                    Circle().fill(Theme.fillStrong)
                                        .matchedGeometryEffect(id: "tab", in: tabNS)
                                }
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressStyle())
                    .help(m.title)
                }
                IconButton(symbol: "gearshape", size: 10, help: "Settings") {
                    vm.close()
                    SettingsWindow.show()
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder private var module: some View {
        switch vm.tab {
        case .nowPlaying: NowPlayingView()
        case .shelf: ShelfView()
        case .clipboard: ClipboardView()
        case .calendar: CalendarView()
        case .timers: TimersView()
        case .claude: ClaudeView()
        case .tools: QuickToolsView(close: { vm.close() })
        case .stats: StatsView()
        case .camera: CameraView()
        }
    }
}
