WORD :: u16;
HLOCAL :: HANDLE;

MEMORY_BASIC_INFORMATION :: struct {
    BaseAddress : *void;
    AllocationBase: *void;
    AllocationProtect: DWORD;
    PartitionId: WORD;
    RegionSize: int;
    State: DWORD;
    Protect: DWORD;
    Type: DWORD;
}

VirtualQuery :: (lpAddress: *void, mbi: *MEMORY_BASIC_INFORMATION, len: int) -> int #foreign kernel32;
LocalFree :: (hMem: HLOCAL) -> HLOCAL #foreign kernel32;

// Returns the last Win32 error, in string format. Returns an empty string if there is no error.
GetLastErrorAsString :: () -> string {
    // Get the error message ID, if any.
    errorMessageID := GetLastError();
    if errorMessageID == 0 return "";

    messageBuffer: *u16;

    // Ask Win32 to give us the string version of that message ID.
    // The parameters we pass in, tell Win32 to create the buffer that holds the message for us (because we don't yet know how long the message string will be).
    size := FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                           null, errorMessageID, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), *messageBuffer, 0, null);
    if size == 0 {
        assert(false, "Could not FormatMessageW an error!");
        return "Could not FormatMessageW an error!";
    }
    defer LocalFree(messageBuffer);

    // Make a jai string pointing at the string
    message := wide_to_utf8(messageBuffer, size);
            
    return message;
}


#scope_file

kernel32 :: #foreign_system_library "kernel32";
#import "Windows";
#import "Windows_Utf8";
#import "Basic";
