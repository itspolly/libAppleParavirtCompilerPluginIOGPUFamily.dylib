#include "DynamicSymbols.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

// LLVM functions
void (*g_LLVMDisposeMemoryBuffer)(void* buffer) = nullptr;
size_t (*g_LLVMGetBufferSize)(void* buffer) = nullptr;
const char* (*g_LLVMGetBufferStart)(void* buffer) = nullptr;
const char* (*g_LLVMGetTarget)(void* module) = nullptr;
NameResult (*g_llvm_Value_getName)(void* value) = nullptr;
void* (*g_llvm_Module_getNamedMetadata)(void* module, const void* name) = nullptr;
void* (*g_llvm_NamedMDNode_getOperand)(void* namedMD, uint32_t index) = nullptr;

// GPU Compiler functions
void* (*g_LLVMExtraMakeSharedModule)(void* module) = nullptr;
void (*g_LLVMExtraDisposeSharedModule)(void* sharedModule) = nullptr;
int (*g_MTLDowngradeAIRModule)(void* module, uint64_t version, int flags) = nullptr;
void* (*g_MTLGPUCompilerCreate)() = nullptr;
void (*g_MTLGPUCompilerDestroy)(void* compiler) = nullptr;
void* (*g_MTLMetalFunctionCreate)(void* sharedModule, const char* name) = nullptr;
void* (*g_MTLMetalLibCreateExecutableWithTriple)(const char* triple) = nullptr;
void (*g_MTLMetalLibDestroy)(void* metalLib) = nullptr;
void (*g_MTLMetalLibInsertFunction)(void* metalLib, void* function) = nullptr;
void* (*g_MTLWriteMetalLibToMemoryBuffer)(void* metalLib) = nullptr;

// No system function pointers needed - all provided via headers and linking

static void* LoadSymbol(void* handle, const char* name, bool required = true) {
    void* symbol = dlsym(handle, name);
    if (!symbol && required) {
        fprintf(stderr, "Failed to load symbol: %s\n", name);
        return nullptr;
    }
    return symbol;
}

bool InitializeDynamicSymbols() {
    // Load libLLVM.dylib
    void* llvmHandle = dlopen("/usr/lib/libLLVM.dylib", RTLD_LAZY | RTLD_LOCAL);
    if (!llvmHandle) {
        fprintf(stderr, "Failed to load libLLVM.dylib: %s\n", dlerror());
        return false;
    }

    g_LLVMDisposeMemoryBuffer = (void (*)(void*))LoadSymbol(llvmHandle, "LLVMDisposeMemoryBuffer");
    g_LLVMGetBufferSize = (size_t (*)(void*))LoadSymbol(llvmHandle, "LLVMGetBufferSize");
    g_LLVMGetBufferStart = (const char* (*)(void*))LoadSymbol(llvmHandle, "LLVMGetBufferStart");
    g_LLVMGetTarget = (const char* (*)(void*))LoadSymbol(llvmHandle, "LLVMGetTarget");

    // LLVM C++ mangled names
    g_llvm_Value_getName = (NameResult (*)(void*))LoadSymbol(llvmHandle, "_ZNK4llvm5Value7getNameEv");
    g_llvm_Module_getNamedMetadata = (void* (*)(void*, const void*))LoadSymbol(llvmHandle, "_ZNK4llvm6Module16getNamedMetadataERKNS_5TwineE");
    g_llvm_NamedMDNode_getOperand = (void* (*)(void*, uint32_t))LoadSymbol(llvmHandle, "_ZNK4llvm11NamedMDNode10getOperandEj");

    if (!g_LLVMDisposeMemoryBuffer || !g_LLVMGetBufferSize || !g_LLVMGetBufferStart ||
        !g_LLVMGetTarget || !g_llvm_Value_getName || !g_llvm_Module_getNamedMetadata ||
        !g_llvm_NamedMDNode_getOperand) {
        fprintf(stderr, "Failed to load required LLVM symbols\n");
        return false;
    }

    // Load libGPUCompiler.dylib
    void* gpuCompilerHandle = dlopen("/System/Library/PrivateFrameworks/GPUCompiler.framework/Libraries/libGPUCompiler.dylib", RTLD_LAZY | RTLD_LOCAL);
    if (!gpuCompilerHandle) {
        fprintf(stderr, "Failed to load libGPUCompiler.dylib: %s\n", dlerror());
        return false;
    }

    g_LLVMExtraMakeSharedModule = (void* (*)(void*))LoadSymbol(gpuCompilerHandle, "LLVMExtraMakeSharedModule");
    g_LLVMExtraDisposeSharedModule = (void (*)(void*))LoadSymbol(gpuCompilerHandle, "LLVMExtraDisposeSharedModule");
    g_MTLDowngradeAIRModule = (int (*)(void*, uint64_t, int))LoadSymbol(gpuCompilerHandle, "MTLDowngradeAIRModule");
    g_MTLGPUCompilerCreate = (void* (*)())LoadSymbol(gpuCompilerHandle, "MTLGPUCompilerCreate");
    g_MTLGPUCompilerDestroy = (void (*)(void*))LoadSymbol(gpuCompilerHandle, "MTLGPUCompilerDestroy");
    g_MTLMetalFunctionCreate = (void* (*)(void*, const char*))LoadSymbol(gpuCompilerHandle, "MTLMetalFunctionCreate");
    g_MTLMetalLibCreateExecutableWithTriple = (void* (*)(const char*))LoadSymbol(gpuCompilerHandle, "MTLMetalLibCreateExecutableWithTriple");
    g_MTLMetalLibDestroy = (void (*)(void*))LoadSymbol(gpuCompilerHandle, "MTLMetalLibDestroy");
    g_MTLMetalLibInsertFunction = (void (*)(void*, void*))LoadSymbol(gpuCompilerHandle, "MTLMetalLibInsertFunction");
    g_MTLWriteMetalLibToMemoryBuffer = (void* (*)(void*))LoadSymbol(gpuCompilerHandle, "MTLWriteMetalLibToMemoryBuffer");

    if (!g_LLVMExtraMakeSharedModule || !g_LLVMExtraDisposeSharedModule ||
        !g_MTLDowngradeAIRModule || !g_MTLGPUCompilerCreate || !g_MTLGPUCompilerDestroy ||
        !g_MTLMetalFunctionCreate || !g_MTLMetalLibCreateExecutableWithTriple ||
        !g_MTLMetalLibDestroy || !g_MTLMetalLibInsertFunction || !g_MTLWriteMetalLibToMemoryBuffer) {
        fprintf(stderr, "Failed to load required GPU Compiler symbols\n");
        return false;
    }

    // Note: System symbols (os_log_*, __stack_chk_guard) are provided via standard headers
    // and libSystem.B.dylib linkage - no need to dlopen
    //
    // Note: Exception handling symbols (__cxa_*) are provided by libc++.1.dylib
    // via -stdlib=libc++ linkage - no need to dlopen

    return true;
}

// Constructor to initialize symbols on load
__attribute__((constructor))
static void InitializeOnLoad() {
    if (!InitializeDynamicSymbols()) {
        fprintf(stderr, "Fatal: Failed to initialize dynamic symbols\n");
        exit(1);
    }
}
