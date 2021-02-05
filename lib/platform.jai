request_window_close :: (native_handle: *void) {
    #if OS == .WINDOWS {
        PostMessageW :: (hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> BOOL #foreign user32;
        PostMessageW(native_handle, WM_CLOSE, 0, 0);
    }
}

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

#if OS == .WINDOWS {
    Windowed_State :: RECT;

    reset_if_empty :: (windowed_state: *Windowed_State, x: s32, y: s32, w: s32, h: s32) {
        if windowed_state.left <= 0   windowed_state.left = x;
        if windowed_state.top <= 0    windowed_state.top = y;
        if windowed_state.right <= 0  windowed_state.right = x + w;
        if windowed_state.bottom <= 0 windowed_state.bottom = y + h;
    }
}

set_window_borderless :: (native_handle: *void, borderless: bool, x: s32, y: s32, w: s32, h: s32) -> Windowed_State {
    rect: RECT;
    rect.left = x;
    rect.top = y;
    rect.right = x + w;
    rect.bottom = y + h;
    return set_window_borderless(native_handle, borderless, *rect);
}

set_window_borderless_fullscreen :: (native_handle: *void) -> Windowed_State {
    windowed_state := set_window_borderless(native_handle, true);
    #if OS == .WINDOWS {
        w := GetSystemMetrics(SM_CXSCREEN);
        h := GetSystemMetrics(SM_CYSCREEN);
        SetWindowPos(native_handle, HWND_TOP, 0, 0, w, h, SWP_FRAMECHANGED);
    }
    return windowed_state;
}

set_window_borderless :: (native_handle: *void, borderless: bool, old_window_info: *RECT = null) -> Windowed_State {
    #if OS == .WINDOWS {
        BORDERLESS_STYLE     :u32 : WS_VISIBLE | WS_POPUP;
        NOT_BORDERLESS_STYLE :u32 : WS_VISIBLE | WS_OVERLAPPEDWINDOW;
        EX_STYLE                 :: WS_EX_APPWINDOW;

        was_rect: RECT;
        GetClientRect(native_handle, *was_rect);
        MapWindowPoints(native_handle, null, cast(*POINT)*was_rect, 2);

        style: u32 = ifx borderless then BORDERLESS_STYLE else NOT_BORDERLESS_STYLE;
        SetWindowLongW(native_handle, GWL_STYLE, cast,trunc(s32)style);
        if old_window_info != null {
            rect := <<old_window_info;
            if !AdjustWindowRectEx(*rect, dwStyle=style, bMenu=BOOL.FALSE, dwExStyle=WS_EX_APPWINDOW)
                logprint("platform", "warning: AdjustWindowRectEx failed");
            SetWindowPos(native_handle, HWND_TOP, rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top, SWP_FRAMECHANGED);
        }

        return was_rect;
    } else {
        logprint("platform", "TODO: implement set_window_borderless for this platform");
    }
}

is_window_borderless :: (native_handle: *void) -> bool {
    #if OS == .WINDOWS
        return !!(GetWindowLongW(native_handle, GWL_STYLE) & WS_POPUP);
    return false;
}


set_window_rect :: (native_handle: *void, x: s32, y: s32, w: s32, h: s32) {
    #if OS == .WINDOWS {
        SetWindowPos(native_handle, HWND_TOP, x, y, w, h, SWP_NOZORDER);
    }
}

get_client_mouse_pos :: (window: *void) -> (x: s32, y: s32) {
    #if OS == .WINDOWS {
        last_point: POINT;
        assert(window != null);
        point: POINT;
        GetCursorPos(*point);
        MapWindowPoints(null, window, *point, 1);
        return point.x, point.y;
    }

    return 0, 0;
}


get_window_position :: (native_handle: *void) -> (x: s32, y: s32) {
    assert(native_handle != null);
    rect: RECT;
    GetWindowRect(native_handle, *rect);
    return rect.left, rect.top;
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

path_exists :: (path: string) -> bool {
    // returns true if path is an existing file or directory.
    assert(path.count > 0);
    attrib:DWORD = GetFileAttributesW(utf8_to_wide(path));
    return attrib != INVALID_FILE_ATTRIBUTES;
}

#scope_file
#if OS == .WINDOWS {
    #import "Windows";
    #import "Windows_Utf8";
    user32 :: #foreign_system_library "user32";
    MapWindowPoints :: (hwnd1: *void, hwnd2: *void, points: *POINT, point_count: u32) -> s32 #foreign user32;
}
#import "Basic";
#import "Math";
