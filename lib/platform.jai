#scope_file
#if OS == .WINDOWS
    #import "Windows";
#import "Basic";
#scope_module

SetWindowAlwaysOnTop :: (native_handle: *void, top := true) {
    #if OS == .WINDOWS {
        insert_after := ifx top then HWND_TOPMOST else HWND_NOTOPMOST;
        SetWindowPos(native_handle, insert_after, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    }
}

IsWindowAlwaysOnTop :: (native_handle: *void) -> bool {
    #if OS == .WINDOWS {
        return GetWindowLongW(native_handle, GWL_EXSTYLE) & WS_EX_TOPMOST != 0;
    }

    return false;
}

toggle :: (native_handle: *void) -> bool {
    top := IsWindowAlwaysOnTop(native_handle);
    new_val := !top;
    SetWindowAlwaysOnTop(native_handle, new_val);
    return new_val;
}
