#!/bin/bash
set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m"

trap 'echo -e "${RED}Build failed!${NC}"; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUST_DIR="${PROJECT_ROOT}/rust-core"
OUTPUT_DIR="${PROJECT_ROOT}/swift-bindings"
BUILD_DIR="${PROJECT_ROOT}/build"
XCFRAMEWORK_NAME="ImgrsCore"
LIB_NAME="libimgrs_core.a"

echo -e "${YELLOW}Building Rust Core Library for macOS${NC}"

if ! command -v rustc >/dev/null 2>&1; then
  echo -e "${RED}Rust not found. Please install Rust (rustc/cargo/rustup) and retry.${NC}"
  exit 1
fi

rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin

mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}"

echo -e "${YELLOW}Building for Apple Silicon (aarch64-apple-darwin)...${NC}"
cargo build --manifest-path "${RUST_DIR}/Cargo.toml" --release --target aarch64-apple-darwin

echo -e "${YELLOW}Building for Intel (x86_64-apple-darwin)...${NC}"
cargo build --manifest-path "${RUST_DIR}/Cargo.toml" --release --target x86_64-apple-darwin

echo -e "${YELLOW}Generating Swift bindings with UniFFI...${NC}"
(cd "${RUST_DIR}" && cargo run --bin uniffi-bindgen generate \
  --library "${RUST_DIR}/target/aarch64-apple-darwin/release/${LIB_NAME}" \
  --language swift \
  --out-dir "${OUTPUT_DIR}")

echo -e "${YELLOW}Creating universal binary with lipo...${NC}"
mkdir -p "${BUILD_DIR}/universal"
lipo -create \
  "${RUST_DIR}/target/aarch64-apple-darwin/release/${LIB_NAME}" \
  "${RUST_DIR}/target/x86_64-apple-darwin/release/${LIB_NAME}" \
  -output "${BUILD_DIR}/universal/${LIB_NAME}"
lipo -info "${BUILD_DIR}/universal/${LIB_NAME}"

echo -e "${YELLOW}Preparing XCFramework structure...${NC}"
mkdir -p "${BUILD_DIR}/headers"
cp "${OUTPUT_DIR}/imgrs_coreFFI.h" "${BUILD_DIR}/headers/"
cp "${OUTPUT_DIR}/imgrs_coreFFI.modulemap" "${BUILD_DIR}/headers/module.modulemap"

echo -e "${YELLOW}Creating XCFramework...${NC}"
rm -rf "${PROJECT_ROOT}/${XCFRAMEWORK_NAME}.xcframework"
xcodebuild -create-xcframework \
  -library "${BUILD_DIR}/universal/${LIB_NAME}" \
  -headers "${BUILD_DIR}/headers" \
  -output "${PROJECT_ROOT}/${XCFRAMEWORK_NAME}.xcframework"

echo -e "${GREEN}Build complete!${NC}"
echo
echo "Generated artifacts:"
echo "- XCFramework: ${PROJECT_ROOT}/${XCFRAMEWORK_NAME}.xcframework"
echo "- Swift bindings: ${OUTPUT_DIR}/*.swift"
echo "- Header: ${OUTPUT_DIR}/imgrs_coreFFI.h"
echo "- Module map: ${OUTPUT_DIR}/imgrs_coreFFI.modulemap"
echo
echo "Next steps:"
echo "- Add ${XCFRAMEWORK_NAME}.xcframework to your Xcode project"
echo "- Add Swift bindings from swift-bindings/ to your Xcode project"
echo "- Import ImgrsCore in your Swift code"
