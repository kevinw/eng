InitializeApp       :: (app_name: *u8, license_type: License_Type) -> Client_Error #foreign HoloPlayCore_lib "hpc_InitializeApp";
TeardownMessagePipe :: () #foreign HoloPlayCore_lib "hpc_TeardownMessagePipe";

GetNumDevices       :: () -> s32 #foreign HoloPlayCore_lib "hpc_GetNumDevices";

GetDevicePropertyWinX          :: (dev_index: s32) -> s32   #foreign HoloPlayCore_lib "hpc_GetDevicePropertyWinX";
GetDevicePropertyWinY          :: (dev_index: s32) -> s32   #foreign HoloPlayCore_lib "hpc_GetDevicePropertyWinY";
GetDevicePropertyScreenW       :: (dev_index: s32) -> s32   #foreign HoloPlayCore_lib "hpc_GetDevicePropertyScreenW";
GetDevicePropertyScreenH       :: (dev_index: s32) -> s32   #foreign HoloPlayCore_lib "hpc_GetDevicePropertyScreenH";
GetDevicePropertyInvView       :: (dev_index: s32) -> s32   #foreign HoloPlayCore_lib "hpc_GetDevicePropertyInvView";
GetDevicePropertyRi            :: (dev_index: s32) -> s32   #foreign HoloPlayCore_lib "hpc_GetDevicePropertyRi";
GetDevicePropertyBi            :: (dev_index: s32) -> s32   #foreign HoloPlayCore_lib "hpc_GetDevicePropertyBi";
GetDevicePropertyPitch         :: (dev_index: s32) -> float #foreign HoloPlayCore_lib "hpc_GetDevicePropertyPitch";
GetDevicePropertyCenter        :: (dev_index: s32) -> float #foreign HoloPlayCore_lib "hpc_GetDevicePropertyCenter";
GetDevicePropertyTilt          :: (dev_index: s32) -> float #foreign HoloPlayCore_lib "hpc_GetDevicePropertyTilt";
GetDevicePropertyFringe        :: (dev_index: s32) -> float #foreign HoloPlayCore_lib "hpc_GetDevicePropertyFringe";
GetDevicePropertySubp          :: (dev_index: s32) -> float #foreign HoloPlayCore_lib "hpc_GetDevicePropertySubp";


// Error code returned from libHoloPlayCore.dll
// (i.e., we did not get a roundtrip message/response for some reason)
Client_Error :: enum s32 {
    NOERROR;            // no error, everything ok
    NOSERVICE;          // HoloPlay Service not installed or not running
    VERSIONERR;         // HoloPlay Service / HoloPlay Core version mismatch
    SERIALIZEERR;       // Something wrong with serilization of message data being sent to HoloPlay Service
    DESERIALIZEERR;     // Something wrong with serilization of message data being received from HoloPlay Service 
    MSGTOOBIG;          // Message sent was too large and was rejected
    SENDTIMEOUT;        // HoloPlay Service was detected but did not consume message
    RECVTIMEOUT;        // HoloPlay Service received message but did not respond
    PIPEERROR;          // Some other problem with communication
    APPNOTINITIALIZED;  // hpc_RefreshState called before hpc_InitializeApp
}

// Error code returned from Holoplay Service.
// (we got a response, but it contains an error flag)
Service_Error :: enum s32 {
    NOERROR;               // no error, everything ok
    BADCBOR;               // HoloPlay Service could not deserialize message as sent
    BADCOMMAND;            // Message as parsed is invalid or not allowed
    NOIMAGE;               // HoloPlay Service expected image data in the message but did not receive any
    LKGNOTFOUND;           // Command refers to a Looking Glass that isn't connected
    NOTINCACHE;            // Command requested that HoloPlay Service load a cached quilt image that doesn't exist
    INITTOOLATE;           // App tried to initialize with appid after it had already sent messages
    NOTALLOWED;            // Action requested by command isn't allowed for some other reason
    INTERNAL1;             // Don't worry about this one :)
}

License_Type :: enum s32 {
    NONCOMMERCIAL;
    COMMERCIAL;
}

#if OS == .WINDOWS {
    HoloPlayCore_lib :: #foreign_library "win/dll/HoloPlayCore";
}
