import SwiftUI
import UniformTypeIdentifiers

struct NotchRootView: View {
    @ObservedObject var vm: NotchViewModel

    var body: some View {
        let size = vm.bodySize
        let ear = vm.topRadius
        let shape = NotchShape(topRadius: ear, bottomRadius: vm.bottomRadius)

        ZStack(alignment: .top) {
            shape.fill(Theme.surface)

            Group {
                if vm.phase == .open {
                    OpenView(vm: vm)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                                .animation(Springs.soft.delay(0.05)),
                            removal: .opacity.animation(.easeOut(duration: 0.12))))
                } else {
                    ClosedView(vm: vm)
                        .transition(.opacity.animation(.easeOut(duration: 0.15)))
                }
            }
            .padding(.horizontal, ear)
            .frame(width: size.width + 2 * ear, height: size.height, alignment: .top)
        }
        .frame(width: size.width + 2 * ear, height: size.height)
        .clipShape(shape)
        .overlay {
            if vm.isDropTargeted {
                shape.stroke(Theme.ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .padding(.horizontal, ear)
            }
        }
        .shadow(color: .black.opacity(vm.phase == .open ? 0.5 : 0), radius: 18, y: 8)
        .contentShape(shape)
        .onDrop(of: [.fileURL], isTargeted: $vm.isDropTargeted) { vm.drop($0) }
        .animation(vm.phase == .open ? Springs.open : Springs.close, value: vm.phase)
        .animation(Springs.snap, value: vm.activity.category)
        .animation(Springs.snap, value: vm.isDropTargeted)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}
