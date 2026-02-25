# libAppleParavirtCompilerPluginIOGPUFamily.dylib Recreation

**NOTE: this repository contains AI-generated code and is untested**

A recreation of `libAppleParavirtCompilerPluginIOGPUFamily.dylib` for use with the PCC VRE iPhone image.

## Overview

This binary is a Metal shader compiler plugin that processes LLVM AIR (Apple Intermediate Representation) modules and converts them into Metal libraries. It's part of the GPU compiler stack for paravirtualized GPU support on Apple Silicon.

## Architecture

### Core Components

1. **AppleParavirtCompiler** (C++ class)
   - Main compiler class with a vtable-based interface
   - Size: 24 bytes (vtable pointer + 2 member variables)
   - Members:
     - `memoryBuffer` (offset +8): Stores the compiled Metal library buffer
     - `gpuCompiler` (offset +16): GPU compiler instance handle

2. **C API Wrapper Functions**
   - `MTLCompilerCreate()`: Creates and initializes a compiler instance
   - `MTLCompilerDelete()`: Destroys a compiler instance
   - `MTLCompilerBuildRequestWithOptions()`: Compiles an LLVM module to Metal library
   - `MTLCompilerReleaseReply()`: Releases the memory buffer

3. **Dynamic Symbol Loading**
   - All external dependencies are loaded via `dlopen`/`dlsym` (weak linking)
   - Dependencies:
     - `libLLVM.dylib`: LLVM C/C++ APIs
     - `libGPUCompiler.dylib`: Metal GPU compiler APIs
     - `libSystem.dylib`: System functions and logging
     - `libc++abi.dylib`: C++ exception handling

### Key Functions

#### `buildRequestWithOptions()`
The main compilation pipeline:
1. Downgrades AIR module to version 2.2
2. Searches for entry point metadata (`air.vertex`, `air.fragment`, or `air.kernel`)
3. Extracts the function name from metadata
4. Creates a Metal library executable with the target triple
5. Wraps the LLVM module as a shared module
6. Creates a Metal function from the entry point
7. Writes the Metal library to a memory buffer
8. Returns buffer pointer and size

#### Entry Point Metadata
The compiler looks for three types of Metal shader entry points:
- `"air.vertex"` - Vertex shaders
- `"air.fragment"` - Fragment shaders
- `"air.kernel"` - Compute kernels

## Building

### Requirements
- Xcode Command Line Tools
- iOS SDK with arm64e support
- Access to iOS system frameworks (libLLVM.dylib, libGPUCompiler.dylib)

### Compilation

```bash
cd src
chmod +x build.sh
./build.sh
```

This will produce: `./src/build/libAppleParavirtCompilerPluginIOGPUFamily.dylib`

### Build Configuration

The binary is compiled with:
- **Architecture**: arm64e (with pointer authentication)
- **Language**: C++17
- **Standard Library**: libc++
- **Optimization**: -O2
- **Min iOS Version**: 13.0
- **Install Name**: `/System/Library/Extensions/AppleParavirtGPUMetalIOGPUFamily.bundle/Contents/Resources/libAppleParavirtCompilerPluginIOGPUFamily.dylib`

## API Interface

### C API

```c
// Create a compiler instance
AppleParavirtCompiler* MTLCompilerCreate(void);

// Build Metal library from LLVM module
bool MTLCompilerBuildRequestWithOptions(
    AppleParavirtCompiler* compiler,  // a1
    const void* options,              // a2 - scalar
    size_t optionsSize,               // a3 - scalar
    uint32_t flags,                   // a4 - scalar
    void* llvmModule,                 // a5 - scalar
    const void** outDataPtr,          // a6 - pointer
    size_t* outDataSize,              // a7 - pointer
    const void** outParam1,           // a8 - pointer
    size_t* outParam2,                // a9 - pointer
    const void** outParam3,           // a10 - pointer
    size_t* outParam4,                // a11 - pointer
    const char** outError             // a12 - pointer
)

// Release the compiled library buffer
void MTLCompilerReleaseReply(AppleParavirtCompiler* compiler);

// Destroy the compiler instance
void MTLCompilerDelete(AppleParavirtCompiler* compiler);
```

### C++ API

The `AppleParavirtCompiler` class can also be used directly in C++ code:

```cpp
AppleParavirtCompiler compiler;
if (compiler.init()) {
    // Use compiler...
    compiler.deleteCompilerReply();
}
```

## Exported Symbols

The binary exports:
- 4 C API functions
- 6 C++ class methods (mangled names)
- 1 vtable symbol
- 1 global array (`entryPointsMetadata`)

See `exports.txt` for the complete list.

## Implementation Notes

### Weak Linking Strategy

All external symbols are dynamically loaded at runtime using `dlopen`/`dlsym`. This provides:
- **Flexibility**: Works across different iOS versions
- **Isolation**: No direct link-time dependencies
- **Safety**: Graceful handling of missing symbols

The `DynamicSymbols` module handles all symbol resolution with automatic initialization via a constructor function.

### LLVM/Metal Integration

The compiler bridges LLVM's IR representation with Metal's binary format:
1. LLVM Module → AIR downgrade
2. AIR Module → Metal Library (via GPU compiler)
3. Metal Library → Memory buffer (for serialization)

### Exception Handling

The original binary uses C++ exceptions for error reporting. The recreation maintains this behavior with proper exception types and messages.

### VTable Compatibility

The C++ class uses a virtual destructor to ensure proper cleanup and vtable compatibility. The vtable symbol is exported to maintain binary compatibility with any code that performs virtual calls.

## Testing

To verify the binary works correctly:

1. Check exported symbols:
```bash
nm -gU src/build/libAppleParavirtCompilerPluginIOGPUFamily.dylib
```

2. Compare with original:
```bash
nm -gU ./extracted_cache/System/Library/Extensions/AppleParavirtGPUMetalIOGPUFamily.bundle/libAppleParavirtCompilerPluginIOGPUFamily.dylib
```

3. Check architecture:
```bash
file src/build/libAppleParavirtCompilerPluginIOGPUFamily.dylib
lipo -info src/build/libAppleParavirtCompilerPluginIOGPUFamily.dylib
```

Note that `libAppleParavirtCompilerPluginIOGPUFamily.dylib` is missing from this repository due to copyright protections, but it can be extracted with the [ipsw](https://github.com/blacktop/ipsw) CLI:

- `ipsw dyld extract --arch arm64e dyld_shared_cache_arm64e ./extracted_cache`
- `cd extracted_cache`
- `find . -name "*AppleParavirtCompilerPluginIOGPUFamily*"`

You should find `./extracted_cache/System/Library/Extensions/AppleParavirtGPUMetalIOGPUFamily.bundle/libAppleParavirtCompilerPluginIOGPUFamily.dylib` which can be used for the testing performed above.

## Files

- `src/AppleParavirtCompiler.h` - Public API header
- `src/AppleParavirtCompiler.mm` - Main implementation (Objective-C++)
- `src/DynamicSymbols.h` - Dynamic symbol declarations
- `src/DynamicSymbols.cpp` - Dynamic symbol loader implementation
- `src/exports.txt` - Exported symbols list
- `src/build.sh` - Build script

## Notes

- This is a clean-room recreation based on reverse engineering the original binary
- The public interface matches exactly to maintain compatibility
- Internal implementation may differ from the original while maintaining the same behavior
- Requires iOS system frameworks at runtime (libLLVM, libGPUCompiler)
