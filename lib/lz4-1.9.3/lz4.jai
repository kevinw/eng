#module_parameters(LINK_STATIC := false);

LZ4_VERSION_MAJOR ::    1;    /* for breaking interface changes  */
LZ4_VERSION_MINOR ::    9;    /* for new (non-breaking) interface capabilities */
LZ4_VERSION_RELEASE ::  3;    /* for tweaks, bug-fixes, or development */

LZ4_VERSION_NUMBER :: (LZ4_VERSION_MAJOR *100*100 + LZ4_VERSION_MINOR *100 + LZ4_VERSION_RELEASE);
//LZ4_LIB_VERSION :: #run sprint("%.%.%", LZ4_VERSION_MAJOR, LZ4_VERSION_MINOR, LZ4_VERSION_RELEASE);


LZ4_versionNumber :: () -> s32 #foreign lz4;
LZ4_versionString :: () -> *u8 #foreign lz4;

// Simple functions.
LZ4_compress_default :: (source: *u8, dest: *u8, sourceSize: s32, maxDestSize: s32) -> s32 #foreign lz4;
LZ4_decompress_safe :: (source: *u8, dest: *u8, compressedSize: s32, maxDecompressedSize: s32) -> s32 #foreign lz4;

// Advanced functions.
LZ4_MAX_INPUT_SIZE :u32:       0x7E000000;   /* 2 113 929 216 bytes */
LZ4_COMPRESSBOUND :: inline (isize: u32) -> u32 {
    if isize > LZ4_MAX_INPUT_SIZE return 0;
    return isize + (isize/255) + 16;
}

LZ4_compressBound :: (inputSize: s32) -> s32 #foreign lz4;
LZ4_compress_fast :: (source: *u8, dest: *u8, sourceSize: s32, maxDestSize: s32, acceleration: s32) -> s32 #foreign lz4;
LZ4_sizeofState :: () -> s32 #foreign lz4;
LZ4_compress_fast_extState :: (state: *void, source: *u8, dest: *u8, inputSize: s32, maxDestSize: s32, acceleration: s32) -> s32 #foreign lz4;
LZ4_compress_destSize :: (source: *u8, dest: *u8, sourceSizePtr: *s32, targetDestSize: s32) -> s32 #foreign lz4;
LZ4_decompress_safe_partial :: (source: *u8, dest: *u8, compressedSize: s32, targetOutputSize: s32, maxDecompressedSize: s32) -> s32 #foreign lz4;

// Streaming Compression Functions
LZ4_stream_t :: void;

LZ4_createStream :: () -> *LZ4_stream_t #foreign lz4;
LZ4_freeStream :: (streamPtr: *LZ4_stream_t) -> s32 #foreign lz4;
LZ4_resetStream_fast :: (streamPtr: *LZ4_stream_t) #foreign lz4;

LZ4_loadDict :: (streamPtr: *LZ4_stream_t, dictionary: *u8, dictSize: s32) -> s32 #foreign lz4;
LZ4_compress_fast_continue :: (streamPtr: *LZ4_stream_t, src: *u8, dst: *u8, srcSize: s32, maxDstSize: s32, acceleration: s32) -> s32 #foreign lz4;
LZ4_saveDict :: (streamPtr: *LZ4_stream_t, safeBuffer: *u8, dictSize: s32) -> s32 #foreign lz4;

// Bufferless synchronous API
LZ4_streamDecode_t :: void;

LZ4_createStreamDecode :: () -> *LZ4_streamDecode_t #foreign lz4;
LZ4_freeStreamDecode :: (LZ4_stream: *LZ4_streamDecode_t) -> s32 #foreign lz4;
LZ4_setStreamDecode :: (LZ4_streamDecode: *LZ4_streamDecode_t, dictionary: *u8, dictSize: s32) -> s32 #foreign lz4;

LZ4_decoderRingBufferSize :: (maxBlockSize: s32) -> s32 #foreign lz4;
LZ4_DECODER_RING_BUFFER_SIZE :: inline (maxBlockSize: s32) -> s32 { return (65536 + 14 + (maxBlockSize)); }

LZ4_decompress_safe_continue :: (LZ4_streamDecode: *LZ4_streamDecode_t, source: *u8, dest: *u8, compressedSize: s32, maxDecompressedSize: s32) -> s32 #foreign lz4;
LZ4_decompress_safe_usingDict :: (source: *u8, dest: *u8, compressedSize: s32, maxDecompressedSize: s32, dictStart: *u8, dictSize: s32) -> s32 #foreign lz4;

// LZ4_HC
LZ4HC_CLEVEL_MIN ::         3;
LZ4HC_CLEVEL_DEFAULT ::     9;
LZ4HC_CLEVEL_OPT_MIN ::    10;
LZ4HC_CLEVEL_MAX ::        12;

LZ4_compress_HC :: (src: *u8, dst: *u8, srcSize: s32, dstCapacity: s32, compressionLevel: s32) -> s32 #foreign lz4;

// Deprecated APIs
LZ4_decompress_fast :: (source: *u8, dest: *u8, originalSize: s32) -> s32 #foreign lz4 #deprecated "This function is deprecated and unsafe. Consider using LZ4_decompress_safe() instead";
LZ4_decompress_fast_continue :: (LZ4_streamDecode: *LZ4_streamDecode_t, source: *u8, dest: *u8, originalSize: s32) -> s32 #foreign lz4 #deprecated "This function is deprecated and unsafe. Consider using LZ4_decompress_safe_continue() instead";
LZ4_decompress_fast_usingDict :: (source: *u8, dest: *u8, originalSize: s32, dictStart: *u8, dictSize: s32) -> s32 #foreign lz4 #deprecated "This function is deprecated and unsafe. Consider using LZ4_decompress_safe_usingDict() instead";
LZ4_resetStream :: (streamPtr: *LZ4_stream_t) #foreign lz4 #deprecated "Consider switching to LZ4_initStream()";


#scope_file

#if OS == .MACOS    lz4 :: #foreign_library "mac/liblz4";
#if OS == .WINDOWS  {
    #if LINK_STATIC {
        lz4 :: #foreign_library,no_dll "win/static/liblz4_static";
    } else {
        lz4 :: #foreign_library "win/dll/liblz4";
    }
}
#if OS == .LINUX    lz4 :: #foreign_library "linux/liblz4";
