# Reverse engineering and producing a binary compatible /System/Library/Extensions/AppleParavirtGPUMetalIOGPUFamily.bundle/Contents/Resources/libAppleParavirtCompilerPluginIOGPUFamily.dylib

## Instructions

- For imported symbols, use weak linking (dlopen) to open the modules and dlsym to find the symbols
- Ensure your binary's public interface matches exactly: AppleParavirtCompiler must have the same vtable as in libAppleParavirtCompilerPluginIOGPUFamily.dylib
- If connection to IDA MCP fails stop and output exactly that, along with any output needed for debugging
- You must call `close_idb` when work with IDA is done (preferably close the db regularly so changes are persisted if the agent encounters an issue, the default state should be closed, do not close the db when an open request is in progress.)
- Use nm to check that the exported symbols of the original binary fully match the symbols of the generated code

## Tips

- See `symtab.txt` for exported and imported symbols.
- Use the ipsw command `ipsw` to analyse the shared cache: presumably you will want to lookup where the symbols it links against are for reverse engineering their arguments
- Useful `ipsw` commands: 
    - `ipsw dyld macho <cache> <module>`
        - `-n` to list symbols
    - `ipsw dyld info -l <cache>`
    - `ipsw dyld search <cache>`
    - `ipsw help` or `ipsw <command> help`
        - i urge you to use these before starting work
- If you encounter an unresolved address use `ipsw dsc a2s <cache> <address> --image --mapping -V` to find where that symbol lives, and then use the open_dsc ida mcp tool to analyse that binary: wait until analysis has finished before proceeding.
    - This tool can be used to open the right module into the currently open ida db.
- Use IDA Pro MCP's `open_dsc` tool to open `dyld_shared_cache_arm64e` and (it will automatically find and open the preexisting database at `dyld_shared_cache_arm64e.i64`) and `open_dsc` to open other images into the same db (it is fine to call open_dsc more than once: it will add the specified image and module to the database) and `analyze_funcs` to run auto analysis on the newly opened files.
- Use the `task_status` tool and `analysis_status` tools to wait until the `dyld_shared_cache_arm64e.i64` database has been opened and to wait for `open_dsc` calls
- As a matter of **last resort** there is an extracted binary (`libAppleParavirtCompilerPluginIOGPUFamily.dylib`) in `cwd`: but note that this binary was extracted using `ipsw dsc extract` and is imperfect: **prefer using IDA for your reverse engineering work**.
