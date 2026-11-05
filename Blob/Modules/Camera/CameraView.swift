import SwiftUI
import AVFoundation

struct CameraView: View {
    @EnvironmentObject private var camera: CameraService

    var body: some View {
        HStack(spacing: 14) {
            preview
            VStack(alignment: .leading, spacing: 12) {
                DevicePicker(title: "Camera", symbol: "camera", current: camera.currentCameraName,
                             items: camera.cameras.map { (id: $0.id, name: $0.name) },
                             selected: camera.selectedCameraID ?? camera.cameras.first?.id) { id in
                    if let cam = camera.cameras.first(where: { $0.id == id }) { camera.selectCamera(cam) }
                }
                DevicePicker(title: "Microphone", symbol: "mic", current: camera.currentMicName,
                             items: camera.microphones.map { (id: String($0.id), name: $0.name) },
                             selected: String(camera.selectedMicID)) { id in
                    if let mic = camera.microphones.first(where: { String($0.id) == id }) { camera.selectMicrophone(mic) }
                }
                Spacer(minLength: 0)
            }
            .frame(width: 190)
        }
        .onAppear { camera.setVisible(true) }
        .onDisappear { camera.setVisible(false) }
    }

    @ViewBuilder private var preview: some View {
        if !camera.hasCamera {
            EmptyState(text: "No camera found", mood: .sleepy)
        } else if camera.status != .authorized {
            EmptyState(text: "Mirror", detail: "Check yourself before a call. The camera only runs while this tab is open.",
                       mood: .curious, actionTitle: "Allow camera") { camera.requestAccess() }
        } else {
            CameraPreview(session: camera.box.session)
                .scaleEffect(x: -1, y: 1) // mirror
                .aspectRatio(16 / 10, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A quiet menu: label, current choice, and a checkmark list.
private struct DevicePicker: View {
    let title: String
    let symbol: String
    let current: String
    let items: [(id: String, name: String)]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(text: title)
            Menu {
                ForEach(items, id: \.id) { item in
                    Button {
                        onSelect(item.id)
                    } label: {
                        if item.id == selected { Label(item.name, systemImage: "checkmark") } else { Text(item.name) }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.secondary)
                    Text(current).font(Theme.font(12, .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.tertiary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .disabled(items.isEmpty)
        }
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
