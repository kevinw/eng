#if OS == .WINDOWS {
gen_guid :: () -> string {
    // TODO: this is a pretty wasteful way to generate a GUID
    // we should probably just use some simple code instead of
    // calling into windows ole32.dll
    guid: GUID;
    res := CoCreateGuid(*guid);
    assert(res == S_OK, "CoCreateGuid failed");

    buf: [40]u16;
    count := StringFromGUID2(*guid, buf.data, buf.count);
    assert(count > 0, "StringFromGUID2 failed");

    without_braces: string;
    {
        Push_Temporary();
        guid_str := wide_to_utf8(buf.data, count);
        assert(guid_str.count == 38, "count was %", guid_str.count);
        assert(guid_str[0] == #char "{" && guid_str[guid_str.count - 1] == #char "}");
        without_braces = slice(guid_str, 1, guid_str.count - 2);
    }
    return replace(without_braces, "-", "");
}
}

#scope_file

#import "Basic";
#import "String";

#if OS == .WINDOWS {
    #import "Windows";
    #import "Windows_Utf8";
    ole32 :: #system_library "ole32";
    CoCreateGuid :: (guid: *GUID) -> HRESULT #foreign ole32;
    StringFromGUID2 :: (guid: *GUID, str_buf: *u16, str_buf_max: s32) -> s32 #foreign ole32;
}
