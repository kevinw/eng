#scope_file

#if OS == .WINDOWS {
    miniz_lib :: #foreign_library,no_dll "win/miniz";
}

#scope_module

/* Return status codes. MZ_PARAM_ERROR is non-standard. */
Status_Code :: enum s32 {
    OK :: 0;
    STREAM_END :: 1;
    NEED_DICT :: 2;
    ERRNO :: -1;
    STREAM_ERROR :: -2;
    DATA_ERROR :: -3;
    MEM_ERROR :: -4;
    BUF_ERROR :: -5;
    VERSION_ERROR :: -6;
    PARAM_ERROR :: -10000;
}

/* Compression levels: 0-9 are the standard zlib-style levels, 10 is best possible compression (not zlib compatible, and may be very slow), MZ_DEFAULT_COMPRESSION=MZ_DEFAULT_LEVEL. */
Compression_Level :: enum s32 {
    MZ_NO_COMPRESSION :: 0;
    MZ_BEST_SPEED :: 1;
    MZ_BEST_COMPRESSION :: 9;
    MZ_UBER_COMPRESSION :: 10;
    MZ_DEFAULT_LEVEL :: 6;
    MZ_DEFAULT_COMPRESSION :: -1;
};

/* Single-call compression functions mz_compress() and mz_compress2(): */
/* Returns Status_Code.OK on success, or one of the error codes from mz_deflate() on failure. */
compress  :: (dest: *u8, dest_len: *u64, source: *u8, source_len: u64) -> Status_Code #foreign miniz_lib "mz_compress";
compress2 :: (dest: *u8, dest_len: *u64, source: *u8, source_len: u64, level: s32) -> Status_Code #foreign miniz_lib "mz_compress2";

/* Single-call decompression. */
/* Returns Status_Code.OK on success, or one of the error codes from mz_inflate() on failure. */
uncompress :: (dest: *u8, dest_len: *u64, source: *u8, source_len: u64) -> Status_Code #foreign miniz_lib "mz_uncompress";

/* Returns a string description of the specified error code, or NULL if the error code is invalid. */
error :: (err: s32) -> *u8 #foreign miniz_lib "mz_error";