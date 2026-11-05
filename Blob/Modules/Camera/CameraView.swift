import SwiftUI
import AVFoundation

struct CameraView: View {
    @EnvironmentObject private var camera: CameraService

    var body: some View {
        Group {
            if !camera.hasCamera {
                EmptyState(text: "No camera found", mood: .sleepy)
            } else if camera.status != .authorized {
                EmptyState(text: "Mirror", detail: "Check yourself before a call. The camera only runs while this tab is open.",
                           mood: .curious, actionTitle: "Allow camera") { camera.requestAccess() }
            } else {
                CameraPreview(session: camera.box.session)
                    .scaleEffect(x: -1, y: 1) // mirror
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { camera.setVisible(true) }
        .onDisappear { camera.setVisible(false) }
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
