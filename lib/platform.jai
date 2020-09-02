#scope_file
#if OS == .WINDOWS #import "Windows";
#import "Basic";
#scope_module

set_window_opacity :: (native_handle: *void, opacity: float) {
    #if OS == .WINDOWS {
        user32 :: #foreign_system_library "user32";
        SetLayeredWindowAttributes :: (hwnd: HWND, color_key: u32, alpha: u8, flags: u32) -> s32 #foreign user32;
        LWA_ALPHA :: 0x00000002;

        // Ensure it's a layered window so that we can do transparency.
        SetWindowLongW(
            native_handle, 
            GWL_EXSTYLE, 
            GetWindowLongW(native_handle, GWL_EXSTYLE) | WS_EX_LAYERED);

        // Set the opacity.
        SetLayeredWindowAttributes(
            native_handle,
            0, 
            cast(u8)(opacity * 255),
            LWA_ALPHA
        );
    }
}

is_window_active :: inline (native_handle: *void) -> bool {
    #if OS == .WINDOWS
        return GetActiveWindow() == native_handle;

    return true;
}

set_window_borderless :: (native_handle: *void, borderless: bool) {
    #if OS == .WINDOWS {
        if borderless SetWindowLongW(native_handle, GWL_STYLE, WS_VISIBLE | WS_POPUP);
        else SetWindowLongW(native_handle, GWL_STYLE, WS_VISIBLE | WS_OVERLAPPEDWINDOW);
    }
}

is_window_borderless :: (native_handle: *void) -> bool {
    #if OS == .WINDOWS
        return !(GetWindowLongW(native_handle, GWL_STYLE) & WS_OVERLAPPEDWINDOW);
    return false;
}

get_window_size :: (native_handle: *void) -> (w: s32, h: s32) {
    #if OS == .WINDOWS {
        win_rect: RECT;
        GetClientRect(native_handle, *win_rect);
        return win_rect.right - win_rect.left, win_rect.bottom - win_rect.top;
    }
}

set_window_always_on_top :: (native_handle: *void, top := true) {
    #if OS == .WINDOWS {
        insert_after := ifx top then HWND_TOPMOST else HWND_NOTOPMOST;
        SetWindowPos(native_handle, insert_after, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    }
}

is_window_always_on_top :: inline (native_handle: *void) -> bool {
    #if OS == .WINDOWS
        return GetWindowLongW(native_handle, GWL_EXSTYLE) & WS_EX_TOPMOST != 0;
    return false;
}

toggle_always_on_top :: (native_handle: *void) -> bool {
    new_val := !is_window_always_on_top(native_handle);
    set_window_always_on_top(native_handle, new_val);
    return new_val;
}