main_socket :: () {
    #import "Basic";

    SOCKET :: s32;

    sockaddr :: struct {
        sa_family: u16;
        sa_data: [14]u8;
    };

    sockaddr_in :: struct {
        sin_family : u16;     // Address family
        sin_port   : u16;     // Port number
        sin_addr   : in_addr; // IP address
        sin_zero   : [8]u8;    // Pad to size of 'sockaddr'
    };

    in_addr :: struct {
        s_addr     : u32;
    }

    ws2_32 :: #system_library "ws2_32";
    WORD               :: u16;
    WSASYS_STATUS_LEN  :: 128;
    WSADESCRIPTION_LEN :: 256;
    AF_INET            :: 2;
    SOCK_STREAM        :: 1;
    IPPROTO_TCP        :: 6;

    MAKEWORD :: inline (l: u16, h: u16) -> WORD { return (l & 0xff) | ((h & 0xff) << 8); }
    LOBYTE   :: inline (w: WORD) -> u8 { return cast,trunc(u8)(w & 0xff); }
    HIBYTE   :: inline (w: WORD) -> u8 { return cast,trunc(u8)((w >> 8) & 0xff); }

    WSADATA :: struct {
      wVersion:       WORD;
      wHighVersion:   WORD;
      szDescription:  [WSADESCRIPTION_LEN+1]u8;
      szSystemStatus: [WSASYS_STATUS_LEN+1]u8;
      iMaxSockets: u16;
      iMaxUdpDg: u16;
      lpVendorInfo: *u8;
    }

    WSAStartup :: (version_required: WORD, wsa_data: *WSADATA) -> s32 #foreign ws2_32;
    WSACleanup :: () -> s32                     #foreign ws2_32;
    inet_addr  :: (ip4_address_str: *u8) -> u32 #foreign ws2_32;
    htons      :: (hostshort: u16) -> u16       #foreign ws2_32;
    socket     :: (af: s32, type: s32, protocol: s32) -> SOCKET            #foreign ws2_32;
    connect    :: (socket: SOCKET, addr: *sockaddr, addrlen: s32) -> s32   #foreign ws2_32;
    send       :: (socket: SOCKET, buf: *u8, len: s32, flags: s32) -> s32  #foreign ws2_32;
    recv       :: (socket: SOCKET, buf: *u8, len: s32, flags: s32) -> s32  #foreign ws2_32;

    wVersionRequested := MAKEWORD(2, 2);

    wsa_data: WSADATA;
    err := WSAStartup(wVersionRequested, *wsa_data);
    if err != 0 {
        // Tell the user that we could not find a usable Winsock DLL.
        print("WSAStartup failed with error: %\n", err);
        exit(1);
    }

    if (LOBYTE(wsa_data.wVersion) != LOBYTE(wVersionRequested) ||
        HIBYTE(wsa_data.wVersion) != HIBYTE(wVersionRequested))
    {
        // Tell the user that we could not find a usable WinSock DLL.
        print("Could not find a usable version of Winsock.dll\n");
        WSACleanup();
        exit(1);
    }

    server_address: sockaddr_in;
    server_address.sin_family = AF_INET;
    server_address.sin_port = htons(80);
    server_address.sin_addr.s_addr = inet_addr("216.58.202.14");
    sock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP); 
    header := "GET / HTTP/1.1\r\nhost: www.youtube.com\r\n\r\n";

    response_len:s32 = 5000;
    response := talloc(response_len);

    connection := connect(sock, cast(*sockaddr)*server_address, size_of(type_of(server_address)));
    if connection != 0 {
        print("error connecting\n");
        exit(1);
    }

    if send(sock, header.data, cast(s32)header.count, 0) < 0 {
        print("error sending\n");
        exit(1);
    }
    print("Sent\n");   

    if recv(sock, response, response_len, 0) < 0 {
        print("error receiving\n");
        exit(1);
    }

    print("response:\n%\n", to_string(response));

    print("OK!\n");
}

main :: () {
    #import "Windows";
    #import "Windows_Utf8";

    ERROR_PIPE_BUSY       :: 231;
    PIPE_READMODE_MESSAGE:DWORD : 0x00000002;

    kernel32 :: #system_library "kernel32";
    WaitNamedPipeA :: (lpNamedPipeName: *u8, nTimeOut: DWORD) -> BOOL #foreign kernel32;
    SetNamedPipeHandleState :: (
      hNamedPipe: HANDLE,
      lpMode: *DWORD,
      lpMaxCollectionCount: *DWORD,
      lpCollectDataTimeout: *DWORD
    ) -> BOOL #foreign kernel32;

    pipe_name :: "\\\\.\\pipe\\tmp\\holoplay-driver.ipc";

    pipe: HANDLE;
    while 1 {
        pipe = CreateFileW(
            utf8_to_wide(pipe_name),
            FILE_GENERIC_READ | FILE_GENERIC_WRITE, // read and write access
            0, // no sharing
            null, // default security attributes
            OPEN_EXISTING, // open existing pipe
            0, // default attributes
            null // no template file
        );

        if pipe != INVALID_HANDLE_VALUE {
            break;
        }

        if GetLastError() != ERROR_PIPE_BUSY {
            print("Could not open pipe. GLE=%\n", GetLastError());
            exit(1);
        }

        if !WaitNamedPipeA(pipe_name, 2000) { 
            print("Could not open pipe: 2 second wait timed out.\n"); 
            exit(1);
        } 
    }

    print("got pipe: %\n", pipe);

    // The pipe connected; change to message-read mode. 
     
    /*
    dwMode:DWORD = PIPE_READMODE_MESSAGE; 
    fSuccess := SetNamedPipeHandleState( 
        pipe,    // pipe handle 
        *dwMode,  // new pipe mode 
        null,     // don't set maximum bytes 
        null);    // don't set maximum time 
    if !fSuccess {
        print("SetNamedPipeHandleState failed. GLE=%\n", GetLastError()); 
        exit(1);
    }
    */

    //cbToWrite = (lstrlen(lpvMessage)+1)*sizeof(TCHAR);
    //_tprintf( TEXT("Sending %d byte message: \"%s\"\n"), cbToWrite, lpvMessage); 
    message := "Default message";

    bytes_written: s32;
    fSuccess := WriteFile( 
        pipe,                  // pipe handle 
        message.data,          // message 
        cast(s32)message.count,// message length 
        *bytes_written,        // bytes written 
        null);                 // not overlapped 

    if !fSuccess {
       print("WriteFile to pipe failed. GLE=%\n", GetLastError()); 
       exit(1);
    }

    while true { 
        read_buf_len :: 2000;
        read_buf: [read_buf_len]u8;

        bytes_read: u32;

        ERROR_MORE_DATA :: 234;

        // Read from the pipe. 
        fSuccess = ReadFile( 
            pipe,                  // pipe handle 
            read_buf.data,         // buffer to receive reply 
            read_buf.count,        // size of buffer 
            *bytes_read,           // number of bytes read 
            null);                 // not overlapped 

        if !fSuccess && GetLastError() != ERROR_MORE_DATA
            break; 

        print("\"%\"\n", read_buf); 

        if fSuccess break;
    }

    if !fSuccess {
        print("ReadFile from pipe failed. GLE=%\n", GetLastError());
        exit(1);
    }
}

#scope_file
