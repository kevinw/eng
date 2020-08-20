#scope_file
#if OS == .WINDOWS #import "Windows";
#import "Basic";
#scope_module

GetWindowSize :: (native_handle: *void) -> (w: s32, h: s32) {
    #if OS == .WINDOWS {
        win_rect: RECT;
        GetClientRect(native_handle, *win_rect);
        return win_rect.right - win_rect.left, win_rect.bottom - win_rect.top;
    }
}

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
