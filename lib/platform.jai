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

set_window_borderless :: (native_handle: *void, borderless: bool, x:s32 = -1, y: s32 = -1, w:s32 = -1, h:s32 = -1) {
    #if OS == .WINDOWS {
        if borderless {
            SetWindowLongW(native_handle, GWL_STYLE, WS_VISIBLE | WS_POPUP);
            if x != -1 {
                assert(y != -1 && w != -1 && h != -1);
                SetWindowPos(native_handle, HWND_TOP, x, y, w, h, SWP_FRAMECHANGED);
            }
        } else {
            SetWindowLongW(native_handle, GWL_STYLE, WS_VISIBLE | WS_OVERLAPPEDWINDOW);
        }
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
        MapWindowPoints :: (hwnd1: *void, hwnd2: *void, points: *POINT, point_count: u32) -> s32 #foreign user32;
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
}
#import "Basic";
#import "Math";
