import Foundation
import CoreGraphics

struct AppImageInfo: Sendable, Hashable {
    let rawValue: ImageInfo

    init(_ rawValue: ImageInfo) {
        self.rawValue = rawValue
    }

    var width: UInt32 { rawValue.width }
    var height: UInt32 { rawValue.height }
    var format: String { rawValue.format }
    var fileSizeBytes: UInt64 { rawValue.fileSizeBytes }
    var path: String { rawValue.path }

    var formattedFileSize: String {
        FileManager.default.formatFileSize(fileSizeBytes)
    }

    var dimensionsString: String {
        "\(width) × \(height)"
    }
}

struct AppResizeOptions: Sendable, Hashable {
    var width: UInt32 = 1024
    var height: UInt32? = nil
    var algorithm: ResizeAlgorithm = .lanczos3
    var outputFormat: OutputFormat = .sameAsInput

    func toResizeOptions() throws -> ResizeOptions {
        try validate()
        return ResizeOptions(
            width: width,
            height: height,
            algorithm: algorithm,
            outputFormat: outputFormat.toUniFFIOutputFormat()
        )
    }

    func validate() throws {
        if width == 0 || width >= 10_000 {
            throw ImageError.InvalidDimensions(message: "Width must be between 1 and 9999")
        }
        if let height, (height == 0 || height >= 10_000) {
            throw ImageError.InvalidDimensions(message: "Height must be between 1 and 9999")
        }
    }
}

struct AppCropOptions: Sendable, Hashable {
    var x: UInt32 = 0
    var y: UInt32 = 0
    var width: UInt32 = 856
    var height: UInt32 = 836
    var outputFormat: OutputFormat = .sameAsInput

    func toCropOptions() throws -> CropOptions {
        try validate()
        return CropOptions(
            x: x,
            y: y,
            width: width,
            height: height,
            outputFormat: outputFormat.toUniFFIOutputFormat()
        )
    }

    func validate() throws {
        if width == 0 {
            throw ImageError.InvalidDimensions(message: "Width must be > 0")
        }
        if height == 0 {
            throw ImageError.InvalidDimensions(message: "Height must be > 0")
        }
    }
}

struct CropRect: Sendable, Hashable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat = 856
    var height: CGFloat = 836
}

enum OutputFormat: String, CaseIterable, Sendable, Hashable {
    case sameAsInput
    case png
    case jpeg
    case webp

    var displayName: String {
        switch self {
        case .sameAsInput: return "Same as input"
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        }
    }

    func toUniFFIOutputFormat() -> String? {
        switch self {
        case .sameAsInput:
            return nil
        case .png:
            return "png"
        case .jpeg:
            return "jpeg"
        case .webp:
            return "webp"
        }
    }
}

extension ResizeAlgorithm: CaseIterable {
    public static var allCases: [ResizeAlgorithm] {
        [.nearest, .bilinear, .lanczos3]
    }

    public var displayName: String {
        switch self {
        case .nearest:
            return "Nearest (Fastest)"
        case .bilinear:
            return "Bilinear (Balanced)"
        case .lanczos3:
            return "Lanczos3 (Highest Quality)"
        }
    }
}
