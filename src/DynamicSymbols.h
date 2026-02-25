#ifndef DYNAMIC_SYMBOLS_H
#define DYNAMIC_SYMBOLS_H

#include <stdint.h>
#include <stddef.h>
#include <os/log.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize all dynamic symbols (call this before using any functions)
bool InitializeDynamicSymbols();

// LLVM functions from libLLVM.dylib
extern void (*g_LLVMDisposeMemoryBuffer)(void* buffer);
extern size_t (*g_LLVMGetBufferSize)(void* buffer);
extern const char* (*g_LLVMGetBufferStart)(void* buffer);
extern const char* (*g_LLVMGetTarget)(void* module);

// LLVM C++ functions
struct NameResult {
    const char* data;
    size_t length;
};
extern NameResult (*g_llvm_Value_getName)(void* value);
extern void* (*g_llvm_Module_getNamedMetadata)(void* module, const void* name);
extern void* (*g_llvm_NamedMDNode_getOperand)(void* namedMD, uint32_t index);

// GPU Compiler functions from libGPUCompiler.dylib
extern void* (*g_LLVMExtraMakeSharedModule)(void* module);
extern void (*g_LLVMExtraDisposeSharedModule)(void* sharedModule);
extern int (*g_MTLDowngradeAIRModule)(void* module, uint64_t version, int flags);
extern void* (*g_MTLGPUCompilerCreate)(int createFlags);
extern void (*g_MTLGPUCompilerDestroy)(void* compiler);
extern void* (*g_MTLMetalFunctionCreate)(void* sharedModule, const char* name);
extern void* (*g_MTLMetalLibCreateExecutableWithTriple)(const char* triple);
extern void (*g_MTLMetalLibDestroy)(void* metalLib);
extern void (*g_MTLMetalLibInsertFunction)(void* metalLib, void* function);
extern void* (*g_MTLWriteMetalLibToMemoryBuffer)(void* metalLib);

// Note: System functions (os_log_*, __stack_chk_guard) are provided automatically
// via <os/log.h> and libSystem.B.dylib linkage - no need to dlopen them
//
// Note: Exception handling symbols (__cxa_*) are provided automatically by libc++.1.dylib
// via -stdlib=libc++ linkage - no need to dlopen them

#ifdef __cplusplus
}
#endif

#endif // DYNAMIC_SYMBOLS_H
