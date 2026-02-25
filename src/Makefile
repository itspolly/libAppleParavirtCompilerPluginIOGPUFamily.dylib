# Makefile for libAppleParavirtCompilerPluginIOGPUFamily.dylib

# Compiler and flags
CXX = clang++
ARCH_TARGET = arm64e-apple-ios13.0
SDK = $(shell xcrun --sdk iphoneos --show-sdk-path)
INSTALL_NAME = /System/Library/Extensions/AppleParavirtGPUMetalIOGPUFamily.bundle/Contents/Resources/libAppleParavirtCompilerPluginIOGPUFamily.dylib

# Directories
BUILD_DIR = build
SRC_DIR = .

# Flags
CXXFLAGS = -target $(ARCH_TARGET) \
           -isysroot $(SDK) \
           -std=c++17 \
           -stdlib=libc++ \
           -O2 \
           -fexceptions \
           -fvisibility=hidden \
           -I$(SRC_DIR)

LDFLAGS = -target $(ARCH_TARGET) \
          -isysroot $(SDK) \
          -dynamiclib \
          -install_name $(INSTALL_NAME) \
          -compatibility_version 1.0 \
          -current_version 1.0 \
          -Wl,-exported_symbols_list,$(SRC_DIR)/exports.txt \
          -stdlib=libc++ \
          -lobjc \
          -framework Foundation

# Source files
SOURCES = DynamicSymbols.cpp AppleParavirtCompiler.mm
OBJECTS = $(BUILD_DIR)/DynamicSymbols.o $(BUILD_DIR)/AppleParavirtCompiler.o

# Target
TARGET = $(BUILD_DIR)/libAppleParavirtCompilerPluginIOGPUFamily.dylib

.PHONY: all clean info

all: $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp | $(BUILD_DIR)
	@echo "Compiling $<..."
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.mm | $(BUILD_DIR)
	@echo "Compiling $<..."
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(TARGET): $(OBJECTS)
	@echo "Linking $(TARGET)..."
	$(CXX) $(LDFLAGS) $(OBJECTS) -o $(TARGET)
	@echo ""
	@echo "Build complete!"
	@echo ""

info: $(TARGET)
	@echo "Binary info:"
	@file $(TARGET)
	@echo ""
	@echo "Exported symbols:"
	@nm -gU $(TARGET)
	@echo ""
	@echo "Dependencies:"
	@otool -L $(TARGET)

clean:
	rm -rf $(BUILD_DIR)
	@echo "Build directory cleaned."

help:
	@echo "Available targets:"
	@echo "  all    - Build the dylib (default)"
	@echo "  info   - Show information about the built binary"
	@echo "  clean  - Remove build artifacts"
	@echo "  help   - Show this help message"
