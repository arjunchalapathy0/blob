import SwiftUI
import UIKit

/// Choose Blob's home screen icon: dark (default) or light.
struct IconPicker: View {
    @State private var light = UIApplication.shared.alternateIconName == "AppIconLight"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "App icon")
            HStack(spacing: 14) {
                option(title: "Blob", image: "IconPreviewBlob", selected: !light) { set(false) }
                option(title: "Light", image: "IconPreviewLight", selected: light) { set(true) }
                Spacer()
            }
        }
        .sensoryFeedback(.selection, trigger: light)
    }

    private func option(title: String, image: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(image).resizable().frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .padding(3)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(selected ? Theme.ink : .clear, lineWidth: 2))
                Text(title).font(Theme.font(12, .medium)).foregroundStyle(selected ? Theme.ink : Theme.secondary)
            }
        }
        .buttonStyle(PressStyle())
    }

    private func set(_ wantLight: Bool) {
        guard UIApplication.shared.supportsAlternateIcons, wantLight != light else { return }
        UIApplication.shared.setAlternateIconName(wantLight ? "AppIconLight" : nil) { error in
            if error == nil { Task { @MainActor in light = wantLight } }
        }
    }
}
