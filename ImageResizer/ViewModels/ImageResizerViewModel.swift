import Foundation
import Observation

#if canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
final class ImageResizerViewModel {
    var selectedImageURL: URL?
    var originalImageInfo: AppImageInfo?

    var targetWidth: String = ""
    var targetHeight: String = ""
    var lockAspectRatio: Bool = true

    var selectedAlgorithm: ResizeAlgorithm = .lanczos3
    var selectedFormat: OutputFormat = .sameAsInput

    var outputURL: URL?

    var isProcessing: Bool = false
    var resultInfo: AppImageInfo?
    var errorMessage: String?
    var supportedFormats: [String] = []

    var canResize: Bool {
        guard selectedImageURL != nil else { return false }
        guard outputURL != nil else { return false }
        guard let width = parseUInt32(targetWidth), (1...9999).contains(Int(width)) else { return false }
        if lockAspectRatio {
            return true
        }
        guard let height = parseUInt32(targetHeight), (1...9999).contains(Int(height)) else { return false }
        return true
    }

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
        outputURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
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

        outputURL = FileManager.default.generateOutputPath(from: url, format: selectedFormat)
        Task { await loadImageInfo(url) }
    }

    func loadImageInfo(_ url: URL) async {
        errorMessage = nil

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
        panel.nameFieldStringValue = outputURL?.lastPathComponent ?? "image_resized"
        panel.directoryURL = outputURL?.deletingLastPathComponent()
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)

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
