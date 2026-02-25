#ifndef APPLE_PARAVIRT_COMPILER_H
#define APPLE_PARAVIRT_COMPILER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque type for the compiler
typedef struct AppleParavirtCompiler AppleParavirtCompiler;

// C API functions
AppleParavirtCompiler* MTLCompilerCreate(void);
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
