import Foundation

extension FileManager {
    func formatFileSize(_ bytes: UInt64) -> String {
        let units: [(suffix: String, divisor: Double)] = [
            ("B", 1),
            ("KB", 1_024),
            ("MB", 1_024 * 1_024),
            ("GB", 1_024 * 1_024 * 1_024),
        ]

        let value = Double(bytes)
        let unit = units.last(where: { value >= $0.divisor }) ?? units[0]
        let formatted = value / unit.divisor

        if unit.suffix == "B" {
            return "\(Int(formatted)) \(unit.suffix)"
        }
        return String(format: "%.1f %@", formatted, unit.suffix)
    }

    // Back-compat with the name in the implementation plan.
    func formatileSize(_ bytes: UInt64) -> String {
        formatFileSize(bytes)
    }

    func generateOutputPath(from inputURL: URL, format: OutputFormat?, mode: OperationMode) -> URL {
        let directory = inputURL.deletingLastPathComponent()
        let baseName = inputURL.deletingPathExtension().lastPathComponent

        let suffix = mode == .crop ? "_cropped" : "_resized"

        let ext: String
        switch format ?? .sameAsInput {
        case .sameAsInput:
            ext = inputURL.pathExtension
        case .png:
            ext = "png"
        case .jpeg:
            ext = "jpg"
        case .webp:
            ext = "webp"
        }

        let filename = ext.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(ext)"
        return directory.appendingPathComponent(filename)
    }

    func generateOutputPath(from inputURL: URL, format: OutputFormat?) -> URL {
        generateOutputPath(from: inputURL, format: format, mode: .resize)
    }

    func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        let known = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tiff", "tif", "heic", "heif", "avif"]
        return known.contains(ext)
    }
}

extension URL {
    var fileSize: UInt64? {
        (try? resourceValues(forKeys: [.fileSizeKey])).flatMap { values in
            values.fileSize.map(UInt64.init)
        }
    }

    var imageFormat: String? {
        let ext = pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }
}

extension String {
    func toFileURL() -> URL? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed)
    }

    static func fromFileURL(_ url: URL) -> String {
        url.path
    }
}
