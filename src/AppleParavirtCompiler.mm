#include "AppleParavirtCompiler.h"
#include "DynamicSymbols.h"
#include <string>
#include <stdexcept>
#include <cstring>
#include <dlfcn.h>
#include <assert.h>
#include <os/log.h>

// Forward declarations for LLVM types
namespace llvm {
    class Module;
    class Value;
    class NamedMDNode;
}

// Entry point metadata - the compiler searches for these named metadata nodes
static const char* kEntryPointVertex = "air.vertex";
static const char* kEntryPointFragment = "air.fragment";
static const char* kEntryPointKernel = "air.kernel";

extern "C" __attribute__((visibility("default"))) const char* entryPointsMetadata[3] = {
    kEntryPointVertex,
    kEntryPointFragment,
    kEntryPointKernel
};

// LLVM Twine-like wrapper for string references
// This matches the structure used by LLVM's C++ API
struct TwineWrapper {
    uint8_t data[24];  // Opaque data matching Twine size

    TwineWrapper(const char* str) {
        memset(data, 0, sizeof(data));
        // Simple C string Twine - kind = 3 for C string
        if (*str) {
            *(void**)&data[0] = (void*)str;
            data[16] = 3;  // CString kind
            data[17] = 1;  // Valid flag
        } else {
            data[16] = 1;  // Empty kind
            data[17] = 1;  // Valid flag
        }
    }
};

// AppleParavirtCompiler C++ class
class __attribute__((visibility("default"))) AppleParavirtCompiler {
public:
    void* memoryBuffer;                      // Offset +8
    void* gpuCompiler;                       // Offset +16
    AppleParavirtCompilerTargetInfo targetInfo;  // Offset +24 (NEW in PCC version, 8 bytes)

    AppleParavirtCompiler() : memoryBuffer(nullptr), gpuCompiler(nullptr), targetInfo{0} {}

    __attribute__((visibility("default")))
    virtual ~AppleParavirtCompiler();

    __attribute__((visibility("default"), noinline))
    bool init(const AppleParavirtCompilerTargetInfo* target) {
        // PCC version: Store target info at offset +24
        // Disassembly shows: LDR X8, [X1]; STR X8, [X0,#0x18]
        if (target) {
            targetInfo = *target;  // Copy the struct (dereference pointer)
        }

        // CRITICAL FIX: MTLGPUCompilerCreate takes 1 argument (not 0)
        // Disassembly shows: MOV W0, #1; BL _MTLGPUCompilerCreate
        gpuCompiler = g_MTLGPUCompilerCreate(1);
        if (!gpuCompiler) {
            if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR)) {
                os_log_error(OS_LOG_DEFAULT, "Failed to create GPU compiler");
            }
            __assert_rtn("init", "AppleParavirtCompiler.mm", 77, "false");
            return false;
        }
        return true;
    }

    __attribute__((visibility("default"), noinline))
    bool buildRequestWithOptions(
        const void* options,
        size_t optionsSize,
        uint32_t flags,
        llvm::Module* llvmModule,
        const void** outDataPtr,   // PS1_ = void const**
        size_t* outDataSize,       // Pm = unsigned long*
        const void** outParam1,    // S5_ = void const**
        size_t* outParam2,         // S6_ = unsigned long*
        const void** outParam3,    // S5_ = void const**
        size_t* outParam4,         // S6_ = unsigned long*
        const char** outError      // PPKc = char const**
    ) {
        memoryBuffer = nullptr;

        if (!llvmModule) {
            std::logic_error err("LLVM module is null");
            throw err;
        }

        // Downgrade AIR module to version 2.2
        int downgradeResult = g_MTLDowngradeAIRModule(llvmModule, 0x200000002ULL, 0);

        if (downgradeResult == 0) {
            *outError = nullptr;
            return false;
        }

        if (!gpuCompiler) {
            std::logic_error err("GPU compiler not initialized");
            throw err;
        }

        // Find entry point metadata in the LLVM module
        // Only one of the three entry point types should exist per module
        const char* entryPointName = nullptr;
        size_t entryPointLength = 0;

        for (int i = 0; i < 3; i++) {
            TwineWrapper wrapper(entryPointsMetadata[i]);
            llvm::NamedMDNode* namedMD = (llvm::NamedMDNode*)g_llvm_Module_getNamedMetadata(llvmModule, &wrapper);

            if (namedMD) {
                // Found the entry point metadata - extract name and break immediately
                // Get the first operand (metadata node)
                void* operand = g_llvm_NamedMDNode_getOperand(namedMD, 0);
                if (!operand) {
                    std::logic_error err("Named metadata operand is null");
                    throw err;
                }

                // Extract the function name from the metadata
                // The metadata structure contains:
                // - operand + 8: num_operands (uint32)
                // - operand - 8*num_operands: array of operand pointers
                uint32_t numOps = *(uint32_t*)((char*)operand + 8);
                if (numOps == 0) {
                    std::logic_error err("No operands in metadata");
                    throw err;
                }

                // Get first operand (should be a metadata node)
                void** opsArray = (void**)((char*)operand - 8 * (int64_t)numOps);
                uint8_t* elem = (uint8_t*)opsArray[0];
                if (!elem) {
                    std::logic_error err("Element is null");
                    throw err;
                }

                // Check element kind (should be 1 or 2)
                uint8_t kind = elem[0];
                if (kind - 1 >= 2) {
                    std::logic_error err("Invalid element kind");
                    throw err;
                }

                // Get the Value pointer at offset 128
                llvm::Value* value = *(llvm::Value**)(elem + 128);
                if (!value) {
                    std::logic_error err("Value is null");
                    throw err;
                }

                // Check value flag at offset 16
                if (*(uint8_t*)((char*)value + 16)) {
                    std::logic_error err("Value flag check failed");
                    throw err;
                }

                // Get the name using LLVM API
                NameResult nameResult = g_llvm_Value_getName(value);
                entryPointName = nameResult.data;
                entryPointLength = nameResult.length;
                break;
            }
        }

        // Get target triple from module
        const char* target = g_LLVMGetTarget(llvmModule);

        // Create Metal library executable
        void* metalLib = g_MTLMetalLibCreateExecutableWithTriple(target);

        // Make shared module wrapper
        void* sharedModule = g_LLVMExtraMakeSharedModule(llvmModule);

        // Convert entry point name to C string for Metal function creation
        std::string entryPointStr;
        if (entryPointName && entryPointLength > 0) {
            entryPointStr.assign(entryPointName, entryPointLength);
        }

        // Create Metal function with entry point name
        void* metalFunction = g_MTLMetalFunctionCreate(sharedModule, entryPointStr.c_str());
        if (!metalFunction) {
            std::logic_error err("Failed to create Metal function");
            throw err;
        }

        // Insert function into library
        g_MTLMetalLibInsertFunction(metalLib, metalFunction);

        // Write Metal library to memory buffer
        memoryBuffer = g_MTLWriteMetalLibToMemoryBuffer(metalLib);
        if (!memoryBuffer) {
            std::logic_error err("Failed to write Metal library to buffer");
            throw err;
        }

        // Clean up temporary objects
        g_MTLMetalLibDestroy(metalLib);
        g_LLVMExtraDisposeSharedModule(sharedModule);

        // Set output parameters
        *outDataPtr = g_LLVMGetBufferStart(memoryBuffer);
        *outDataSize = g_LLVMGetBufferSize(memoryBuffer);
        *outParam1 = nullptr;
        *outParam2 = 0;
        *outParam3 = nullptr;
        *outParam4 = 0;
        *outError = nullptr;

        return true;
    }

    // Note: This method is exported but NOT virtual (not in vtable)
    // It's a public API that can be called by external code
    // MTLCompilerReleaseReply() has identical logic (duplicated in original)
    __attribute__((visibility("default"), noinline, used))
    void deleteCompilerReply() {
        if (memoryBuffer) {
            g_LLVMDisposeMemoryBuffer(memoryBuffer);
            memoryBuffer = nullptr;
        }
    }
};

// Destructor implementation (out-of-line to generate D0, D1, and D2 variants)
AppleParavirtCompiler::~AppleParavirtCompiler() {
    if (gpuCompiler) {
        g_MTLGPUCompilerDestroy(gpuCompiler);
        gpuCompiler = nullptr;
    }
}

// C API implementation
extern "C" {

__attribute__((visibility("default")))
AppleParavirtCompiler* MTLCompilerCreate(const AppleParavirtCompilerTargetInfo* targetInfo, size_t targetInfoSize) {
    // PCC version: Validate size parameter (must be 8 bytes)
    // Disassembly shows: CMP X1, #8; B.NE return_nullptr
    if (targetInfoSize != sizeof(AppleParavirtCompilerTargetInfo)) {
        return nullptr;
    }

    // Allocate 32 bytes (0x20) - size increased from 24 to accommodate targetInfo
    // Disassembly shows: MOV W0, #0x20; BL operator new
    AppleParavirtCompiler* compiler = new AppleParavirtCompiler();
    if (!compiler->init(targetInfo)) {
        delete compiler;
        return nullptr;
    }
    return compiler;
}

__attribute__((visibility("default")))
void MTLCompilerDelete(AppleParavirtCompiler* compiler) {
    if (compiler) {
        delete compiler;
    }
}

__attribute__((visibility("default")))
void MTLCompilerReleaseReply(AppleParavirtCompiler* compiler) {
    // Note: Original does NOT call deleteCompilerReply(), it directly accesses memoryBuffer
    // This is duplicated logic but matches the original binary
    if (compiler) {
        void* buffer = compiler->memoryBuffer;
        if (buffer) {
            g_LLVMDisposeMemoryBuffer(buffer);
            compiler->memoryBuffer = nullptr;
        }
    }
}

__attribute__((visibility("default")))
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
) {
    return compiler->buildRequestWithOptions(
        options, optionsSize, flags,
        (llvm::Module*)llvmModule,
        outDataPtr, outDataSize,
        outParam1, outParam2, outParam3, outParam4,
        outError
    );
}

} // extern "C"
