#ifndef APPLE_PARAVIRT_COMPILER_H
#define APPLE_PARAVIRT_COMPILER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Target information structure (8 bytes)
// This is passed to MTLCompilerCreate in PCC (iOS 19) version
typedef struct AppleParavirtCompilerTargetInfo {
    uint64_t info;
} AppleParavirtCompilerTargetInfo;

// Opaque type for the compiler
typedef struct AppleParavirtCompiler AppleParavirtCompiler;

// C API functions
// PCC (iOS 19) signature: takes target info and size (must be 8)
AppleParavirtCompiler* MTLCompilerCreate(const AppleParavirtCompilerTargetInfo* targetInfo, size_t targetInfoSize);
void MTLCompilerDelete(AppleParavirtCompiler* compiler);
void MTLCompilerReleaseReply(AppleParavirtCompiler* compiler);

bool MTLCompilerBuildRequestWithOptions(
    AppleParavirtCompiler* compiler,
    const void* options,
    size_t optionsSize,
    uint32_t flags,
    void* llvmModule,
    const void** outDataPtr,
    size_t* outDataSize,
    const void** outParam1,
    size_t* outParam2,
    const void** outParam3,
    size_t* outParam4,
    const char** outError
);

#ifdef __cplusplus
}
#endif

#endif // APPLE_PARAVIRT_COMPILER_H
