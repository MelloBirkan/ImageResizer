import SwiftUI
import Observation
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

struct DropZoneView: View {
    @Bindable var viewModel: ImageResizerViewModel
    @State private var isDragging: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 32, weight: .semibold))

            Text("Drag & drop an image here")
                .font(.headline)

            Text("or click to choose a file")
                .foregroundStyle(.secondary)

            if let url = viewModel.selectedImageURL {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(16)
        .background(
            shape
                .fill(isDragging ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .overlay(
            shape
                .stroke(
                    isDragging ? Color.accentColor : Color.secondary,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .opacity(isDragging ? 1.0 : 0.6)
        )
        .contentShape(shape)
        .onTapGesture { openPanel() }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let found = item as? URL {
                url = found
            } else {
                url = nil
            }

            guard let url else {
                return
            }

            Task { @MainActor in
                guard FileManager.default.isImageFile(url) else {
                    viewModel.errorMessage = "Please drop an image file"
                    return
                }
                viewModel.selectImage(url)
            }
        }

        return true
    }

    private func openPanel() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectImage(url)
        }
        #endif
    }
}
