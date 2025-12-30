import Foundation
import Observation
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

enum OperationMode: String, CaseIterable {
    case resize
    case crop

    var displayName: String {
        switch self {
        case .resize: return "Resize"
        case .crop: return "Crop"
        }
    }
}

@MainActor
@Observable
final class ImageResizerViewModel {
    var operationMode: OperationMode = .resize

    var selectedImageURL: URL?
    var originalImageInfo: AppImageInfo?

    var targetWidth: String = ""
    var targetHeight: String = ""
    var lockAspectRatio: Bool = true

    var selectedAlgorithm: ResizeAlgorithm = .lanczos3
    var selectedFormat: OutputFormat = .sameAsInput

    var cropRect: CropRect = CropRect(x: 0, y: 0)
    var selectedCropFormat: OutputFormat = .sameAsInput
    var cropDisplayedImageSize: CGSize = .zero

    var outputURL: URL?

    var isProcessing: Bool = false
    var resultInfo: AppImageInfo?
    var errorMessage: String?
    var supportedFormats: [String] = []

    var canProcess: Bool {
        guard selectedImageURL != nil else { return false }
        guard outputURL != nil else { return false }

        switch operationMode {
        case .resize:
            guard let width = parseUInt32(targetWidth), (1...9999).contains(Int(width)) else { return false }
            if lockAspectRatio {
                return true
            }
            guard let height = parseUInt32(targetHeight), (1...9999).contains(Int(height)) else { return false }
            return true
        case .crop:
            return true
        }
    }

    var canResize: Bool { canProcess }

    var calculatedHeight: UInt32? {
        guard lockAspectRatio else { return nil }
        guard let original = originalImageInfo else { return nil }
        guard original.width > 0 else { return nil }
        guard let width = parseUInt32(targetWidth) else { return nil }

        let ratio = Double(original.height) / Double(original.width)
        let computed = max(1, Int((Double(width) * ratio).rounded()))
        return UInt32(min(computed, 9999))
    }

    init() {
        outputURL = nil
        loadSupportedFormats()
    }

    func loadSupportedFormats() {
        supportedFormats = getSupportedFormats()
    }

    func selectImage(_ url: URL) {
        selectedImageURL = url
        errorMessage = nil
        resultInfo = nil
        originalImageInfo = nil

        cropRect = CropRect(x: 0, y: 0)
        cropDisplayedImageSize = .zero

        // Output must be user-selected (sandbox) via NSSavePanel.
        outputURL = nil
        Task { await loadImageInfo(url) }
    }

    func loadImageInfo(_ url: URL) async {
        errorMessage = nil

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        if !didAccess, !FileManager.default.isReadableFile(atPath: url.path) {
            errorMessage = "Please re-select the input image"
            return
        }

        do {
            let info = try getImageInfo(path: url.path)

            originalImageInfo = AppImageInfo(info)
            targetWidth = String(info.width)
            targetHeight = String(info.height)
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func updateWidth(_ newWidth: String) {
        targetWidth = sanitizeNumeric(newWidth)
        guard lockAspectRatio else { return }
        if let height = calculatedHeight {
            targetHeight = String(height)
        }
    }

    func updateHeight(_ newHeight: String) {
        targetHeight = sanitizeNumeric(newHeight)

        guard lockAspectRatio else { return }
        guard let original = originalImageInfo else { return }
        guard original.height > 0 else { return }
        guard let height = parseUInt32(targetHeight) else { return }

        let ratio = Double(original.width) / Double(original.height)
        let computed = max(1, Int((Double(height) * ratio).rounded()))
        targetWidth = String(UInt32(min(computed, 9999)))
    }

    func toggleAspectRatio() {
        lockAspectRatio.toggle()
        guard lockAspectRatio else { return }
        if let height = calculatedHeight {
            targetHeight = String(height)
        }
    }

    func selectOutputLocation() {
        #if canImport(AppKit)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if let selectedImageURL {
            let format: OutputFormat = (operationMode == .crop) ? selectedCropFormat : selectedFormat
            let suggested = FileManager.default.generateOutputPath(from: selectedImageURL, format: format, mode: operationMode)
            panel.nameFieldStringValue = suggested.lastPathComponent
        } else {
            panel.nameFieldStringValue = operationMode == .crop ? "image_cropped" : "image_resized"
        }
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            outputURL = url
        }
        #endif
    }

    func resizeImage() async {
        errorMessage = nil
        guard let inputURL = selectedImageURL else {
            errorMessage = "Please select an image"
            return
        }
        guard let outputURL else {
            errorMessage = "Please choose an output location"
            return
        }
        guard let width = parseUInt32(targetWidth), (1...9999).contains(Int(width)) else {
            errorMessage = "Invalid width"
            return
        }
        let height: UInt32?
        if lockAspectRatio {
            height = nil
        } else {
            guard let parsedHeight = parseUInt32(targetHeight), (1...9999).contains(Int(parsedHeight)) else {
                errorMessage = "Invalid height"
                return
            }
            height = parsedHeight
        }

        isProcessing = true
        defer { isProcessing = false }

        let options = ResizeOptions(
            width: width,
            height: height,
            algorithm: selectedAlgorithm,
            outputFormat: selectedFormat.toUniFFIOutputFormat()
        )

        let didAccessInput = inputURL.startAccessingSecurityScopedResource()
        let didAccessOutput = outputURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessInput { inputURL.stopAccessingSecurityScopedResource() }
            if didAccessOutput { outputURL.stopAccessingSecurityScopedResource() }
        }

        if !didAccessInput, !FileManager.default.isReadableFile(atPath: inputURL.path) {
            errorMessage = "Please re-select the input image"
            return
        }

        if !didAccessOutput {
            let dir = outputURL.deletingLastPathComponent()
            if !FileManager.default.isWritableFile(atPath: dir.path) {
                errorMessage = "Please choose an output location"
                return
            }
        }

        do {
            let info = try ImageResizer.resizeImage(
                inputPath: inputURL.path,
                outputPath: outputURL.path,
                options: options
            )
            resultInfo = AppImageInfo(info)
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func cropImage() async {
        errorMessage = nil
        guard let inputURL = selectedImageURL else {
            errorMessage = "Please select an image"
            return
        }
        guard let outputURL else {
            errorMessage = "Please choose an output location"
            return
        }
        guard let originalInfo = originalImageInfo else {
            errorMessage = "Please re-select the input image"
            return
        }
        guard cropDisplayedImageSize.width > 0, cropDisplayedImageSize.height > 0 else {
            errorMessage = "Crop preview not ready"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let imageWidth = CGFloat(originalInfo.width)
        let imageHeight = CGFloat(originalInfo.height)
        guard imageWidth > 0, imageHeight > 0 else {
            errorMessage = "Invalid source image"
            return
        }

        let scaleX = cropDisplayedImageSize.width / imageWidth
        let scaleY = cropDisplayedImageSize.height / imageHeight
        let scale = min(scaleX, scaleY)
        guard scale > 0 else {
            errorMessage = "Crop preview not ready"
            return
        }

        var xPx = UInt32(max(0, (cropRect.x / scale).rounded()))
        var yPx = UInt32(max(0, (cropRect.y / scale).rounded()))
        var wPx = UInt32(max(1, (cropRect.width / scale).rounded()))
        var hPx = UInt32(max(1, (cropRect.height / scale).rounded()))

        let srcW = originalInfo.width
        let srcH = originalInfo.height

        if srcW > 0, xPx >= srcW { xPx = srcW - 1 }
        if srcH > 0, yPx >= srcH { yPx = srcH - 1 }

        let maxW = srcW - xPx
        let maxH = srcH - yPx
        wPx = min(wPx, maxW)
        hPx = min(hPx, maxH)
        if wPx == 0 { wPx = 1 }
        if hPx == 0 { hPx = 1 }

        let options = CropOptions(
            x: xPx,
            y: yPx,
            width: wPx,
            height: hPx,
            outputFormat: selectedCropFormat.toUniFFIOutputFormat()
        )

        let didAccessInput = inputURL.startAccessingSecurityScopedResource()
        let didAccessOutput = outputURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessInput { inputURL.stopAccessingSecurityScopedResource() }
            if didAccessOutput { outputURL.stopAccessingSecurityScopedResource() }
        }

        if !didAccessInput, !FileManager.default.isReadableFile(atPath: inputURL.path) {
            errorMessage = "Please re-select the input image"
            return
        }

        if !didAccessOutput {
            let dir = outputURL.deletingLastPathComponent()
            if !FileManager.default.isWritableFile(atPath: dir.path) {
                errorMessage = "Please choose an output location"
                return
            }
        }

        do {
            let info = try ImageResizer.cropImage(
                inputPath: inputURL.path,
                outputPath: outputURL.path,
                options: options
            )
            resultInfo = AppImageInfo(info)
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func updateCropRect(_ rect: CropRect) {
        cropRect = rect
    }

    private func sanitizeNumeric(_ input: String) -> String {
        input.filter { $0.isNumber }
    }

    private func parseUInt32(_ text: String) -> UInt32? {
        UInt32(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func userMessage(for error: Error) -> String {
        if let error = error as? ImageError {
            switch error {
            case let .IoError(message):
                return "File error: \(message)"
            case let .UnsupportedFormat(format):
                return "Unsupported format: \(format)"
            case let .InvalidDimensions(message):
                return "Invalid dimensions: \(message)"
            case let .ProcessingError(message):
                return "Processing error: \(message)"
            }
        }

        return error.localizedDescription
    }
}
