MARK_UNLOADED_DLLS_AS_NO_ACCESS :: false; // disabled until I figure out why VirtualAlloc with PAGE_NOACCESS is failing after FreeLibrary()

Module :: struct {
    filename: string;
    last_write_time: u64;
    count: u16;

    // win32
    module_info: MODULEINFO;
    native_module: HMODULE;
}

load :: (plugin: *Module, filename: string, COPY_TO_TEMP_PATH := true) -> bool {
    temp_path: string;
    if COPY_TO_TEMP_PATH {
        pdb_filename := tprint("%.pdb", path_strip_extension(filename));

        temp_path = copy_string(tprint("bin\\temp\\temp_%_%.dll", filename, plugin.count));
        temp_pdb_path := tprint("bin\\temp\\temp_%_%.pdb", filename, plugin.count);
        plugin.count += 1;

        if plugin.count > 5 plugin.count = 0; // a hacky way to rotate the DLLs we're writing to...

        // TODO: pdb rewriting stuff (I believe the path or the name of the DLL
        // is hardcoded in the pdb, so there is some stuff online we can use
        // that rewrites that bit here)

        if !_copy_file(filename, temp_path) {
            print("could not copy % to %\n", filename, temp_path);
            return false;
        }

        if file_exists(pdb_filename) {
            _copy_file(pdb_filename, temp_pdb_path);
        }

    } else {
        temp_path = filename;
    }

    // load dll
    log("[plugin] loading % (copied from %)", temp_path, filename);
    new_dll := LoadLibraryA(to_c_string(temp_path));
    if !new_dll {
        log_error("[plugin] could not load '%'", temp_path);
        return false;
    }

    // Here we store the address of the loaded DLL for later.
    if 0 == cast(int)GetModuleInformation(GetCurrentProcess(), new_dll, *plugin.module_info, size_of(type_of(plugin.module_info)))
        log_error("[plugin] GetModuleInformation failed");

    file_time, ok := file_modtime(filename);
    if !ok {
        log_error("[plugin] could not read DLL write time: %", filename);
        return false;
    }
    plugin.last_write_time = file_time;

    plugin.filename = filename;
    plugin.native_module = new_dll;

    return true;
}

file_modtime :: (file_path: string) -> (modtime: u64, success: bool) {
    modtime, size, success := file_modtime_and_size(file_path);
    return modtime, success;
}

unload :: (plugin: *Module) -> bool {
    if plugin.native_module == null return false;

    if !FreeLibrary(plugin.native_module) {
        log_error("[plugin] FreeLibrary(plugin.filename=%) failed with code % - %\n",
            plugin.filename, GetLastError(), GetLastErrorAsString());

        return false;
    }
    
    if MARK_UNLOADED_DLLS_AS_NO_ACCESS {
        // Here we lock the old DLL memory as PAGE_NOACCESS, so that if we
        // accidentally keep a function pointer to it, we'll immediately get a
        // breakpoint when trying to call the function, instead of jumping to
        // random new bytes in memory that are being reused as something else.
        // This should only be used in development/live reload code because it
        // consumes address space.
        using plugin.module_info;
        if lpBaseOfDll != null {
            old_protect_flags: u32;
            size := cast(u64)SizeOfImage;
            valloc_ptr := VirtualAlloc(
                lpBaseOfDll, size, MEM_RESERVE, PAGE_NOACCESS);

            if valloc_ptr == null {
                log_error("[plugin] VirtualAlloc failed. GetLastError(): % - %\n", GetLastError(), GetLastErrorAsString());

                #import "windows_ex";
                mem_basic_info: MEMORY_BASIC_INFORMATION;
                sz := VirtualQuery(lpBaseOfDll, *mem_basic_info, size_of(MEMORY_BASIC_INFORMATION));
                assert(sz != 0);
                log("[plugin] mem_basic_info: %\n", mem_basic_info);

            }
            assert(valloc_ptr != null, "VirtualAlloc(addr=%, size=%, MEM_RESERVE, PAGE_NOACCESS) failed", lpBaseOfDll, size);
        }
    }


    plugin.native_module = null;
    return true;
}

wait_for_readable_file :: (filename: string) -> bool {
    ERROR_SHARING_VIOLATION :: 32;

    while true {
        hFile := CreateFileW(utf8_to_wide(filename), FILE_GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, 0, null);

        if hFile != INVALID_HANDLE_VALUE {
            CloseHandle(hFile);
            break;
        }

        last_err := GetLastError();
        if last_err == ERROR_SHARING_VIOLATION {
            Sleep (100);
        } else {
            log_error("[plugin] an unexpected error while waiting for a file to become readable: % (for file '%')", last_err, filename);
            return false;
        }
    }

    return true;
}

file_modtime_with_busy_loop :: (path: string) -> (u64, bool) {
    file_time: u64;
    ok: bool;

    assert(file_exists(path), 
        tprint(
            "trying to get modtime but file does not exist: '%'",
            path));

    count := 10;
    while count > 0 {
        file_time, ok = file_modtime(path);
        if ok break;

        Sleep(100);
        count -= 1;
    }

    return file_time, ok;
}

should_reload :: (plugin: *Module) -> bool {
    if !plugin.native_module
        return false;

    file_time, ok := file_modtime_with_busy_loop(plugin.filename);

    if !ok {
        log_error("plugin should_reload: could not get modtime: '%'", plugin.filename);
        return false;
    }

    if file_time == plugin.last_write_time
        return false;

    return true;
}

reload :: (plugin: *Module, force_reload := false) -> bool {
    if !plugin.native_module {
        log_error("plugin: there is not native module handle!");
        return false;
    }

    file_time, ok := file_modtime_with_busy_loop(plugin.filename);

    if !ok {
        log_error("plugin could not get modtime: '%'", plugin.filename);
        return false;
    }

    if !force_reload && file_time == plugin.last_write_time {
        log_error("plugin reload: the modification time hasn't changed");
        return false;
    }
    
    plugin.last_write_time = file_time;

    // The jai compiler returns before the linker is done, so here we wait for
    // the file to be readable again.
    if !wait_for_readable_file(plugin.filename) {
        log_error("error waiting for file to become readable");
        return false;
    }

    if !unload(plugin) { // Actually unload the old DLL
        log_error("error tring to unload the old plugin!");
        return false;
    }

    if !load(plugin, plugin.filename) { // Load the new DLL
        log_error("error trying to load the new plugin!");
        return false;
    }

    return true;
}

#scope_file

// some additional win32 api definitions missing from the jai stdlib
wchar_t :: u16;
kernel32 :: #system_library "kernel32";
FreeLibrary :: (module: HANDLE) -> s32 #foreign kernel32;
CopyFileW :: (src: *wchar_t, dest: *wchar_t, force: BOOL) -> s32 #foreign kernel32;

#if OS == .WINDOWS {

_copy_file :: (src: string, dest: string) -> bool {
    fail_if_exists: BOOL = BOOL.FALSE;

    res := CopyFileW(utf8_to_wide(src), utf8_to_wide(dest), fail_if_exists);
    if res == 0 {
        err := GetLastError();
        if err log_error("CopyFileW(src='%', dest='%', fail_if_exists=%) --- GetLastError() returned %", src, dest, fail_if_exists, err);
    }

    return 0 != res;
}

MODULEINFO :: struct {
    lpBaseOfDll: *void;
    SizeOfImage: DWORD;
    EntryPoint: *void;
}

GetModuleInformation :: (
  hProcess: HANDLE,
  hModule: HMODULE,
  lpmodinfo: *MODULEINFO,
  cb: DWORD
) -> BOOL #foreign kernel32 "K32GetModuleInformation";

} // OS == .WINDOWS


#import "Basic";
#import "Windows";
#import "windows_ex";
#import "File";
#import "Windows_Utf8";
#import "File_Utilities";
#import "String";
