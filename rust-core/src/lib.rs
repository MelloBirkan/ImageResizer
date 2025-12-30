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

pub fn get_image_info(path: String) -> Result<ImageInfo, ImageError> {
    todo!("Implementation in next phase")
}

pub fn resize_image(
    input_path: String,
    output_path: String,
    options: ResizeOptions,
) -> Result<ImageInfo, ImageError> {
    todo!("Implementation in next phase")
}

pub fn get_supported_formats() -> Vec<String> {
    todo!("Implementation in next phase")
}

uniffi::include_scaffolding!("imgrs_core");
