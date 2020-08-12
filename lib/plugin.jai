#import "Basic";
#import "Windows";
#import "File";
#import "Windows_Utf8";
#import "File_Utilities";

Module :: struct {
    name: string;
    path_on_disk: string;
    native_module: HMODULE;
    last_write_time: u64;
    count: u16;
}

load :: (plugin: *Module, name: string, COPY_TO_TEMP_PATH := true) -> bool {
    temp_path: string;
    if COPY_TO_TEMP_PATH {
        temp_path = copy_string(tprint("bin\\temp\\temp_%.dll", plugin.count));
        plugin.count += 1;
        // TODO: pdb rewriting stuff (I believe the path or the name of the DLL
        // is hardcoded in the pdb, so there is some stuff online we can use
        // that rewrites that bit here)

        if !_copy_file(name, temp_path) {
            print("could not copy % to %\n", name, temp_path);
            return false;
        }
    } else {
        temp_path = name;
    }

    // load dll
    new_dll := LoadLibraryA(to_c_string(temp_path));
    if !new_dll {
        print("could not load library %\n", name);
        return false;
    }

    file_time, ok := file_modtime(name);
    if !ok {
        print("could not read DLL write time: %\n", name);
        return false;
    }
    plugin.last_write_time = file_time;

    plugin.name = name;
    plugin.native_module = new_dll;
    plugin.path_on_disk = name;

    return true;
}

unload :: (plugin: *Module) -> bool {
    if plugin.native_module == null return false;

    if !FreeLibrary(plugin.native_module) {
        print("error calling FreeLibrary on '%'\n", plugin.native_module);
        return false;
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

        if (GetLastError() == ERROR_SHARING_VIOLATION) {
            Sleep (100);
        } else {
            return false;
        }
    }

    return true;
}

should_reload :: (plugin: *Module) -> bool {
    if !plugin.native_module
        return false;

    file_time, ok := file_modtime(plugin.path_on_disk);

    if !ok {
        print("could not get modtime: '%'\n", plugin.path_on_disk);
        return false;
    }

    if file_time == plugin.last_write_time
        return false;

    return true;
}

reload :: (plugin: *Module) -> bool {
    if !plugin.native_module return false;

    file_time, ok := file_modtime(plugin.path_on_disk);

    if !ok {
        print("could not get modtime: '%'\n", plugin.path_on_disk);
        return false;
    }

    if file_time == plugin.last_write_time
        return false;
    
    plugin.last_write_time = file_time;

    // The jai compiler returns before the linker is done, so here we wait for
    // the file to be readable again.
    if !wait_for_readable_file(plugin.path_on_disk) {
        print("error waiting for file\n");
        return false;
    }

    if !unload(plugin) { // Actually unload the old DLL
        print("error tring to unload the old plugin!\n");
        return false;
    }

    if !load(plugin, plugin.name) { // Load the new DLL
        print("error trying to load the new plugin!\n");
        return false;
    }

    return true;
}

#scope_file

// some additional win32 api definitions missing from the jai stdlib
wchar_t :: u16;
kernel32 :: #foreign_system_library "kernel32";
FreeLibrary :: (module: HANDLE) -> s32 #foreign kernel32;
CopyFileW :: (src: *wchar_t, dest: *wchar_t, force: BOOL) -> s32 #foreign kernel32;

_copy_file :: (src: string, dest: string) -> bool {
    fail_if_exists: BOOL = BOOL.FALSE;

    res := CopyFileW(utf8_to_wide(src), utf8_to_wide(dest), fail_if_exists);
    if res == 0 {
        err := GetLastError();
        if err print("GetLastError() returned %\n", err);
    }

    return 0 != res;
}
