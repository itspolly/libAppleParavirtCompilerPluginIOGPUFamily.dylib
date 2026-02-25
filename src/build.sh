#!/bin/bash

# Build script for libAppleParavirtCompilerPluginIOGPUFamily.dylib
# This recreates the binary with matching public interface

set -e

echo "Building libAppleParavirtCompilerPluginIOGPUFamily.dylib for arm64e..."

# Compiler settings
CC="clang"
CXX="clang++"
ARCH="arm64e"
TARGET="arm64e-apple-ios13.0"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
INSTALL_NAME="/System/Library/Extensions/AppleParavirtGPUMetalIOGPUFamily.bundle/Contents/Resources/libAppleParavirtCompilerPluginIOGPUFamily.dylib"

# Output directory
OUTPUT_DIR="build"
mkdir -p "$OUTPUT_DIR"

# Compile DynamicSymbols.cpp
echo "Compiling DynamicSymbols.cpp..."
$CXX -target $TARGET \
    -isysroot "$SDK" \
    -std=c++17 \
    -stdlib=libc++ \
    -O2 \
    -fexceptions \
    -fvisibility=hidden \
    -c DynamicSymbols.cpp \
    -o "$OUTPUT_DIR/DynamicSymbols.o"

# Compile AppleParavirtCompiler.mm
echo "Compiling AppleParavirtCompiler.mm..."
$CXX -target $TARGET \
    -isysroot "$SDK" \
    -std=c++17 \
    -stdlib=libc++ \
    -O2 \
    -fexceptions \
    -fvisibility=hidden \
    -c AppleParavirtCompiler.mm \
    -o "$OUTPUT_DIR/AppleParavirtCompiler.o"

# Link into dylib
echo "Linking dylib..."
$CXX -target $TARGET \
    -isysroot "$SDK" \
    -dynamiclib \
    -install_name "$INSTALL_NAME" \
    -compatibility_version 1.0 \
    -current_version 1.0 \
    -Wl,-exported_symbols_list,exports.txt \
    -stdlib=libc++ \
    -lobjc \
    -framework Foundation \
    "$OUTPUT_DIR/DynamicSymbols.o" \
    "$OUTPUT_DIR/AppleParavirtCompiler.o" \
    -o "$OUTPUT_DIR/libAppleParavirtCompilerPluginIOGPUFamily.dylib"

# Note: Links against Foundation, libobjc.A.dylib, libc++.1.dylib, and libSystem.B.dylib
# to match original binary's LC_LOAD_DYLIB commands

echo "Done! Output: $OUTPUT_DIR/libAppleParavirtCompilerPluginIOGPUFamily.dylib"

# Show info about the built binary
echo ""
echo "Binary info:"
file "$OUTPUT_DIR/libAppleParavirtCompilerPluginIOGPUFamily.dylib"
echo ""
echo "Exported symbols:"
nm -gU "$OUTPUT_DIR/libAppleParavirtCompilerPluginIOGPUFamily.dylib"
