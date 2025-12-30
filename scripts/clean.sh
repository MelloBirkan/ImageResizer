#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUST_DIR="${PROJECT_ROOT}/rust-core"
OUTPUT_DIR="${PROJECT_ROOT}/swift-bindings"
BUILD_DIR="${PROJECT_ROOT}/build"
XCFRAMEWORK_NAME="ImgrsCore"

echo -e "${YELLOW}Cleaning build artifacts...${NC}"

rm -rf "${RUST_DIR}/target"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
rm -rf "${BUILD_DIR}"
rm -rf "${PROJECT_ROOT}/${XCFRAMEWORK_NAME}.xcframework"
rm -f "${RUST_DIR}/Cargo.lock"

echo -e "${GREEN}All build artifacts cleaned!${NC}"
