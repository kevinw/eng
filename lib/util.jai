// Copy a string and make sure the last byte is null
// Note that the string count will not include the null byte,
// so it operates like a normal Jai string but its data can
// be given to something expecting a null-terminated string.
copy_string_z :: (s: string) -> string {
    r: string;
    r.count = s.count;
    r.data = cast(*u8) alloc(r.count + 1); 
    memcpy(r.data, s.data, s.count);
    r.data[s.count] = 0;
    return r;
}

TString_Builder :: struct {
    using _sb: String_Builder;
    _sb.allocator = __temporary_allocator;
}

tstring :: (sb: *String_Builder) -> string {
    return builder_to_string(sb, __temporary_allocator);
}

#scope_file

#import "Basic";
