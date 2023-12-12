xxh3 :: inline (bytes_string: string) -> [2]u64 {
    return XXH3_128bits(bytes_string.data, cast(u64)bytes_string.count);
}

XXH3_128bits :: (input: *void, len: u64) -> [2]u64 #foreign xxhash_lib;

xxhash_lib :: #library,no_dll "xxHash/xxhash";
