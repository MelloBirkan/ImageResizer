use std::path::Path;

use fast_image_resize as fir;
use image as img;
use img::GenericImageView;

pub struct ImageInfo {
    pub width: u32,
    pub height: u32,
    pub format: String,
    pub file_size_bytes: u64,
    pub path: String,
}

pub enum ResizeAlgorithm {
    Nearest,
    Bilinear,
    Lanczos3,
}

pub struct ResizeOptions {
    pub width: u32,
    pub height: Option<u32>,
    pub algorithm: ResizeAlgorithm,
    pub output_format: Option<String>,
}

#[derive(Debug, thiserror::Error)]
pub enum ImageError {
    #[error("IO error: {message}")]
    IoError { message: String },

    #[error("Unsupported format: {format}")]
    UnsupportedFormat { format: String },

    #[error("Invalid dimensions: {message}")]
    InvalidDimensions { message: String },

    #[error("Processing error: {message}")]
    ProcessingError { message: String },
}

impl From<std::io::Error> for ImageError {
    fn from(err: std::io::Error) -> Self {
        Self::IoError {
            message: err.to_string(),
        }
    }
}

impl From<img::ImageError> for ImageError {
    fn from(err: img::ImageError) -> Self {
        match err {
            img::ImageError::IoError(io_err) => io_err.into(),
            other => Self::ProcessingError {
                message: other.to_string(),
            },
        }
    }
}

impl From<fir::ImageBufferError> for ImageError {
    fn from(err: fir::ImageBufferError) -> Self {
        Self::ProcessingError {
            message: err.to_string(),
        }
    }
}

impl From<fir::ResizeError> for ImageError {
    fn from(err: fir::ResizeError) -> Self {
        Self::ProcessingError {
            message: err.to_string(),
        }
    }
}

fn map_algorithm_to_filter(algorithm: &ResizeAlgorithm) -> fir::ResizeAlg {
    match algorithm {
        ResizeAlgorithm::Nearest => fir::ResizeAlg::Nearest,
        ResizeAlgorithm::Bilinear => fir::ResizeAlg::Convolution(fir::FilterType::Bilinear),
        ResizeAlgorithm::Lanczos3 => fir::ResizeAlg::Convolution(fir::FilterType::Lanczos3),
    }
}

fn calculate_height_with_aspect_ratio(
    original_width: u32,
    original_height: u32,
    target_width: u32,
) -> u32 {
    if original_width == 0 || original_height == 0 || target_width == 0 {
        return 1;
    }

    let height = ((target_width as u64) * (original_height as u64)) / (original_width as u64);
    u32::try_from(height).unwrap_or(1).max(1)
}

fn normalize_format_string(s: &str) -> String {
    s.trim().trim_start_matches('.').to_ascii_lowercase()
}

fn infer_output_format(
    output_path: &str,
    override_format: Option<String>,
) -> Result<img::ImageFormat, ImageError> {
    if let Some(fmt) = override_format {
        let fmt = normalize_format_string(&fmt);
        return img::ImageFormat::from_extension(&fmt)
            .ok_or(ImageError::UnsupportedFormat { format: fmt });
    }

    let ext = Path::new(output_path)
        .extension()
        .and_then(|s| s.to_str())
        .map(normalize_format_string)
        .ok_or(ImageError::UnsupportedFormat {
            format: "<missing extension>".to_string(),
        })?;

    img::ImageFormat::from_extension(&ext).ok_or(ImageError::UnsupportedFormat { format: ext })
}

/// Loads an image from disk and returns basic metadata about it.
///
/// # Parameters
/// - `path`: Path to an image file.
///
/// # Errors
/// Returns an [`ImageError`] if the file can't be read, decoded, or inspected.
///
/// # Example
/// ```no_run
/// use imgrs_core::get_image_info;
///
/// let info = get_image_info("/path/to/image.png".to_string()).unwrap();
/// println!("{}x{}", info.width, info.height);
/// ```
pub fn get_image_info(path: String) -> Result<ImageInfo, ImageError> {
    if path.trim().is_empty() {
        return Err(ImageError::IoError {
            message: "path is empty".to_string(),
        });
    }

    let img = img::open(&path)?;
    let (width, height) = img.dimensions();
    let format = format!("{:?}", img.color());
    let file_size_bytes = std::fs::metadata(&path)?.len();

    Ok(ImageInfo {
        width,
        height,
        format,
        file_size_bytes,
        path,
    })
}

/// Resizes an image from `input_path` into `output_path`.
///
/// If `options.height` is `None`, the height is computed to preserve the original aspect ratio.
///
/// # Parameters
/// - `input_path`: Path to the source image.
/// - `output_path`: Destination path.
/// - `options`: Resize configuration.
///
/// # Errors
/// Returns an [`ImageError`] for invalid dimensions, unsupported formats, or processing failures.
///
/// # Example
/// ```no_run
/// use imgrs_core::{resize_image, ResizeAlgorithm, ResizeOptions};
///
/// let options = ResizeOptions {
///     width: 800,
///     height: None,
///     algorithm: ResizeAlgorithm::Lanczos3,
///     output_format: Some("png".to_string()),
/// };
/// let _info = resize_image(
///     "/path/to/input.jpg".to_string(),
///     "/path/to/output.png".to_string(),
///     options,
/// )
/// .unwrap();
/// ```
pub fn resize_image(
    input_path: String,
    output_path: String,
    options: ResizeOptions,
) -> Result<ImageInfo, ImageError> {
    if input_path.trim().is_empty() {
        return Err(ImageError::IoError {
            message: "input_path is empty".to_string(),
        });
    }
    if output_path.trim().is_empty() {
        return Err(ImageError::IoError {
            message: "output_path is empty".to_string(),
        });
    }
    if options.width == 0 {
        return Err(ImageError::InvalidDimensions {
            message: "width must be > 0".to_string(),
        });
    }
    if matches!(options.height, Some(0)) {
        return Err(ImageError::InvalidDimensions {
            message: "height must be > 0".to_string(),
        });
    }

    let src_dyn = img::open(&input_path)?;
    let (src_width, src_height) = src_dyn.dimensions();

    let dst_width = options.width;
    let dst_height = options
        .height
        .unwrap_or_else(|| calculate_height_with_aspect_ratio(src_width, src_height, dst_width));
    if dst_height == 0 {
        return Err(ImageError::InvalidDimensions {
            message: "computed height is 0".to_string(),
        });
    }

    let src_rgba = src_dyn.to_rgba8();
    let src_buf = src_rgba.into_raw();
    let src_image =
        fir::images::ImageRef::new(src_width, src_height, &src_buf, fir::PixelType::U8x4)?;

    let mut dst_image = fir::images::Image::new(dst_width, dst_height, fir::PixelType::U8x4);

    let fir_options =
        fir::ResizeOptions::new().resize_alg(map_algorithm_to_filter(&options.algorithm));
    let mut resizer = fir::Resizer::new();
    resizer.resize(&src_image, &mut dst_image, Some(&fir_options))?;

    let dst_buf = dst_image.into_vec();
    let dst_rgba = img::RgbaImage::from_raw(dst_width, dst_height, dst_buf).ok_or(
        ImageError::ProcessingError {
            message: "failed to construct RGBA image from resized buffer".to_string(),
        },
    )?;

    let output_format = infer_output_format(&output_path, options.output_format)?;
    let out_dyn = match output_format {
        img::ImageFormat::Jpeg => {
            img::DynamicImage::ImageRgb8(img::DynamicImage::ImageRgba8(dst_rgba).to_rgb8())
        }
        _ => img::DynamicImage::ImageRgba8(dst_rgba),
    };

    out_dyn.save_with_format(&output_path, output_format)?;
    get_image_info(output_path)
}

/// Returns the list of supported output format strings (lowercase, without a dot).
pub fn get_supported_formats() -> Vec<String> {
    vec![
        "png".into(),
        "jpeg".into(),
        "jpg".into(),
        "webp".into(),
        "gif".into(),
        "bmp".into(),
        "tiff".into(),
    ]
}

uniffi::include_scaffolding!("imgrs_core");
