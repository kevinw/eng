#if OS == .WINDOWS
    #import "Windows";

SetWindowAlwaysOnTop :: (native_handle: *void) {
    #if OS == .WINDOWS
        SetWindowPos(native_handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
}