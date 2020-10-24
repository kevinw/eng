RendererDesc :: struct {
}

Renderer :: struct {
}


ResourceMount :: enum {
	/// Installed game directory / bundle resource directory
    CONTENT :: 0;
	/// For storing debug data such as log files. To be used only during development
	DEBUG;
	/// Save game data mount 0
	SAVE_0;
	COUNT;
}

ResourceDirectory :: enum {
	/// The main application's shader binaries directory
    SHADER_BINARIES :: 0;
	/// The main application's shader source directory
	SHADER_SOURCES;

	PIPELINE_CACHE;
	/// The main application's texture source directory (TODO processed texture folder)
	TEXTURES;
	MESHES;
	FONTS;
	ANIMATIONS;
	AUDIO;
	GPU_CONFIG;
	LOG;
	SCRIPTS;
	OTHER_FILES;

	// Libraries can have their own directories.
	// Up to 100 libraries are supported.
	____rd_lib_counter_begin :: cast(ResourceDirectory)(cast(s64)OTHER_FILES + 1);

	// Add libraries here
	MIDDLEWARE_0 :: ____rd_lib_counter_begin;
	MIDDLEWARE_1;
	MIDDLEWARE_2;
	MIDDLEWARE_3;
	MIDDLEWARE_4;
	MIDDLEWARE_5;
	MIDDLEWARE_6;
	MIDDLEWARE_7;
	MIDDLEWARE_8;
	MIDDLEWARE_9;
	MIDDLEWARE_10;
	MIDDLEWARE_11;
	MIDDLEWARE_12;
	MIDDLEWARE_13;
	MIDDLEWARE_14;
	MIDDLEWARE_15;

	____rd_lib_counter_end :: xx ____rd_lib_counter_begin + 99 * 2;
	COUNT;
}

SeekBaseOffset :: enum {
    SBO_START_OF_FILE :: 0;
	SBO_CURRENT_POSITION;
	SBO_END_OF_FILE;
}

FileMode :: enum {
    READ :: 1 << 0;
	WRITE :: 1 << 1;
	APPEND :: 1 << 2;
	BINARY :: 1 << 3;
	ALLOW_READ :: 1 << 4; // Read Access to Other Processes, Usefull for Log System
	READ_WRITE :: READ | WRITE;
	READ_APPEND :: READ | APPEND;
	WRITE_BINARY :: WRITE | BINARY;
	READ_BINARY :: READ | BINARY;
	APPEND_BINARY :: APPEND | BINARY;
	READ_WRITE_BINARY :: READ | WRITE | BINARY;
	READ_APPEND_BINARY :: READ | APPEND | BINARY;
	WRITE_ALLOW_READ :: WRITE | ALLOW_READ;
	APPEND_ALLOW_READ :: READ | ALLOW_READ;
	READ_WRITE_ALLOW_READ :: READ | WRITE | ALLOW_READ;
	READ_APPEND_ALLOW_READ :: READ | APPEND | ALLOW_READ;
	WRITE_BINARY_ALLOW_READ :: WRITE | BINARY | ALLOW_READ;
	APPEND_BINARY_ALLOW_READ :: APPEND | BINARY | ALLOW_READ;
	READ_WRITE_BINARY_ALLOW_READ :: READ | WRITE | BINARY | ALLOW_READ;
	READ_APPEND_BINARY_ALLOW_READ :: READ | APPEND | BINARY | ALLOW_READ;
}

FileStream :: struct {
    pIO: *IFileSystem;
	union
	{
        pFile: *FILE;
        /*
#if OS == .ANDROID {
        pAsset: *AAsset;
} else if OS == .NX64 {
        mStruct: FileNX;
}
        */
        mMemory: MemoryStream;
        pUser: *void;
	};
    mSize: ssize_t;
    mMode: FileMode;
};

FileSystemInitDesc :: struct {
    pAppName: *u8;
    pPlatformData: *void;
	pResourceMounts: [ResourceMount.COUNT]*u8;
}

MemoryStream :: struct {
    pBuffer: *u8;
    mCursor: size_t;
    mOwner: bool;
}

IFileSystem :: struct {
	Open :: #type (pIO: *IFileSystem, resourceDir: ResourceDirectory, fileName: *u8, mode: FileMode, pOut: *FileStream) -> bool;
	Close :: #type (pFile: *FileStream) -> bool;
	Read :: #type (pFile: *FileStream, outputBuffer: *void, bufferSizeInBytes: size_t) -> size_t;
	Write :: #type (pFile: *FileStream, sourceBuffer: *void, byteCount: ssize_t) -> size_t;
	Seek :: #type (pFile: *FileStream, baseOffset: SeekBaseOffset, seekOffset: size_t) -> bool;
	GetSeekPosition :: #type (pFile: *FileStream) -> ssize_t;
	GetFileSize :: #type (pFile: *FileStream) -> ssize_t;
	Flush :: #type (pFile: *FileStream) -> bool;
	IsAtEnd :: #type (pFile: *FileStream) -> bool;
	GetResourceMount :: #type (mount: ResourceMount) -> *u8;

    pUser: *void;
};
//#assert(GetStructSize("IFileSystem") == size_of(IFileSystem));

GetStructSize :: (name: *u8) -> s64 #foreign TF_CAPI "tf_GetStructSize";

Log :: struct {
    Init :: (name: *u8) #foreign TF_CAPI "tf_Log_Init";
    Exit :: () #foreign TF_CAPI "tf_Log_Exit";
}

PlatformStreamOpen :: () #foreign TF_CAPI;
PlatformStreamClose :: () #foreign TF_CAPI;

initRenderer :: (name: *u8, setting: *RendererDesc,  renderer: **Renderer) -> bool #foreign TF_CAPI "tf_initRenderer";
initFileSystem :: (desc: *FileSystemInitDesc) -> bool #foreign TF_CAPI "tf_initFileSystem";
fsSetPathForResourceDir :: (io: *IFileSystem, mount: ResourceMount, resourceDir: ResourceDirectory, bundledFolder: *u8) #foreign TF_CAPI "tf_fsSetPathForResourceDir";
MemAllocInit :: (name: *u8) -> bool #foreign TF_CAPI "tf_MemAllocInit";

get_pSystemFileIO :: () -> *IFileSystem #foreign TF_CAPI "tf_get_pSystemFileIO";

#load "Renderer.jai";

/*
#program_export
stricmp :: (s1: *u8, s2: *u8) -> s32 #c_call {
    return 0;
}
*/

#scope_file


#if OS == .WINDOWS {
    TF_CAPI :: #foreign_library "win/CAPI";
}


size_t  :: u64;
ssize_t :: s64;
FILE :: void;

