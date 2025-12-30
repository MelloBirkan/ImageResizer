import SwiftUI
import Observation

#if canImport(AppKit)
import AppKit
#endif

struct CropView: View {
    @Bindable var viewModel: ImageResizerViewModel
    @State private var nsImage: NSImage?

    var body: some View {
        GroupBox("Crop Preview") {
            GeometryReader { geometry in
                ZStack {
                    if let info = viewModel.originalImageInfo, let nsImage {
                        let imageRect = fittedImageRect(
                            containerSize: geometry.size,
                            imagePixelSize: CGSize(width: CGFloat(info.width), height: CGFloat(info.height))
                        )

                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        CropFrameOverlay(
                            cropRect: $viewModel.cropRect,
                            imageRect: imageRect,
                            displayedImageSize: $viewModel.cropDisplayedImageSize
                        )
                    } else {
                        Text("No image selected")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 400)
        }
        .task(id: viewModel.selectedImageURL) {
            guard let url = viewModel.selectedImageURL else {
                nsImage = nil
                return
            }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }

            nsImage = NSImage(contentsOf: url)
        }
    }

    private func fittedImageRect(containerSize: CGSize, imagePixelSize: CGSize) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else { return .zero }
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else { return .zero }

        let scale = min(containerSize.width / imagePixelSize.width, containerSize.height / imagePixelSize.height)
        let w = imagePixelSize.width * scale
        let h = imagePixelSize.height * scale
        let x = (containerSize.width - w) / 2
        let y = (containerSize.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

private struct CropFrameOverlay: View {
    @Binding var cropRect: CropRect
    let imageRect: CGRect
    @Binding var displayedImageSize: CGSize

    @State private var dragStartRect: CropRect?

    var body: some View {
        let frameWidth: CGFloat = 200
        let frameHeight: CGFloat = frameWidth * (836.0 / 856.0)
        let frameSize = CGSize(width: frameWidth, height: frameHeight)

        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .foregroundColor(.blue)
            .frame(width: frameWidth, height: frameHeight)
            .background(Color.blue.opacity(0.1))
            .position(
                x: imageRect.minX + cropRect.x + frameWidth / 2,
                y: imageRect.minY + cropRect.y + frameHeight / 2
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        displayedImageSize = imageRect.size
                        if dragStartRect == nil {
                            dragStartRect = cropRect
                        }

                        guard var start = dragStartRect else { return }
                        start.width = frameWidth
                        start.height = frameHeight

                        var next = start
                        next.x += value.translation.width
                        next.y += value.translation.height
                        next.width = frameWidth
                        next.height = frameHeight

                        cropRect = clampCropRect(next, imageSize: imageRect.size, frameSize: frameSize)
                    }
                    .onEnded { _ in
                        dragStartRect = nil
                    }
            )
            .onAppear {
                displayedImageSize = imageRect.size
                cropRect.width = frameWidth
                cropRect.height = frameHeight
                cropRect = clampCropRect(cropRect, imageSize: imageRect.size, frameSize: frameSize)
            }
    }

    private func clampCropRect(_ rect: CropRect, imageSize: CGSize, frameSize: CGSize) -> CropRect {
        var r = rect
        r.width = frameSize.width
        r.height = frameSize.height

        let maxX = max(0, imageSize.width - frameSize.width)
        let maxY = max(0, imageSize.height - frameSize.height)

        r.x = min(max(0, r.x), maxX)
        r.y = min(max(0, r.y), maxY)
        return r
    }
}
