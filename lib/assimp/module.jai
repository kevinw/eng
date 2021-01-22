assimp-vc142-mt :: #foreign_library "assimp-vc142-mt";
using aiComponent :: enum s32 {
    aiComponent_NORMALS :: 2;
    aiComponent_TANGENTS_AND_BITANGENTS :: 4;
    aiComponent_COLORS :: 8;
    aiComponent_TEXCOORDS :: 16;
    aiComponent_BONEWEIGHTS :: 32;
    aiComponent_ANIMATIONS :: 64;
    aiComponent_TEXTURES :: 128;
    aiComponent_LIGHTS :: 256;
    aiComponent_CAMERAS :: 512;
    aiComponent_MESHES :: 1024;
    aiComponent_MATERIALS :: 2048;
    _aiComponent_Force32Bit :: -1610612737;
}

ai_real :: float32;

ai_int :: s32;

ai_uint :: u32;

ai_epsilon: ai_real;

aiVector2D :: struct {
    x: ai_real;
    y: ai_real;
}

aiVector3D :: struct {
    x: ai_real;
    y: ai_real;
    z: ai_real;
}

aiColor4D :: struct {
    r: ai_real;
    g: ai_real;
    b: ai_real;
    a: ai_real;
}

aiMatrix3x3 :: struct {
    a1: ai_real;
    a2: ai_real;
    a3: ai_real;
    b1: ai_real;
    b2: ai_real;
    b3: ai_real;
    c1: ai_real;
    c2: ai_real;
    c3: ai_real;
}

aiMatrix4x4 :: struct {
    a1: ai_real;
    a2: ai_real;
    a3: ai_real;
    a4: ai_real;
    b1: ai_real;
    b2: ai_real;
    b3: ai_real;
    b4: ai_real;
    c1: ai_real;
    c2: ai_real;
    c3: ai_real;
    c4: ai_real;
    d1: ai_real;
    d2: ai_real;
    d3: ai_real;
    d4: ai_real;
}

aiQuaternion :: struct {
    w: ai_real;
    x: ai_real;
    y: ai_real;
    z: ai_real;
}

ai_int32 :: int32_t;

ai_uint32 :: uint32_t;

aiPlane :: struct {
    a: ai_real;
    b: ai_real;
    c: ai_real;
    d: ai_real;
}

aiRay :: struct {
    pos: aiVector3D;
    dir: aiVector3D;
}

aiColor3D :: struct {
    r: ai_real;
    g: ai_real;
    b: ai_real;
}

aiString :: struct {
    length: ai_uint32;
    data: [1024] s8;
}

using aiReturn :: enum s32 {
    aiReturn_SUCCESS :: 0;
    aiReturn_FAILURE :: -1;
    aiReturn_OUTOFMEMORY :: -3;
    _AI_ENFORCE_ENUM_SIZE :: 2147483647;
}



using aiOrigin :: enum s32 {
    aiOrigin_SET :: 0;
    aiOrigin_CUR :: 1;
    aiOrigin_END :: 2;
    _AI_ORIGIN_ENFORCE_ENUM_SIZE :: 2147483647;
}

using aiDefaultLogStream :: enum s32 {
    aiDefaultLogStream_FILE :: 1;
    aiDefaultLogStream_STDOUT :: 2;
    aiDefaultLogStream_STDERR :: 4;
    aiDefaultLogStream_DEBUGGER :: 8;
    _AI_DLS_ENFORCE_ENUM_SIZE :: 2147483647;
}

aiMemoryInfo :: struct {
    textures: u32;
    materials: u32;
    meshes: u32;
    nodes: u32;
    animations: u32;
    cameras: u32;
    lights: u32;
    total: u32;
}

using aiImporterFlags :: enum s32 {
    aiImporterFlags_SupportTextFlavour :: 1;
    aiImporterFlags_SupportBinaryFlavour :: 2;
    aiImporterFlags_SupportCompressedFlavour :: 4;
    aiImporterFlags_LimitedSupport :: 8;
    aiImporterFlags_Experimental :: 16;
}

aiImporterDesc :: struct {
    mName: *s8;
    mAuthor: *s8;
    mMaintainer: *s8;
    mComments: *s8;
    mFlags: u32;
    mMinMajor: u32;
    mMinMinor: u32;
    mMaxMajor: u32;
    mMaxMinor: u32;
    mFileExtensions: *s8;
}

aiGetImporterDesc :: (extension: *s8) -> *aiImporterDesc #foreign assimp-vc142-mt;

aiScene :: struct {
}

aiFileIO :: struct {
}

aiLogStreamCallback :: #type (a0: *s8, a1: *s8) -> void #c_call;

aiLogStream :: struct {
    callback: aiLogStreamCallback;
    user: *s8;
}

aiPropertyStore :: struct {
    sentinel: s8;
}

aiBool :: s32;

aiImportFile :: (pFile: *s8, pFlags: u32) -> *aiScene #foreign assimp-vc142-mt;

aiImportFileEx :: (pFile: *s8, pFlags: u32, pFS: *aiFileIO) -> *aiScene #foreign assimp-vc142-mt;

aiImportFileExWithProperties :: (pFile: *s8, pFlags: u32, pFS: *aiFileIO, pProps: *aiPropertyStore) -> *aiScene #foreign assimp-vc142-mt;

aiImportFileFromMemory :: (pBuffer: *s8, pLength: u32, pFlags: u32, pHint: *s8) -> *aiScene #foreign assimp-vc142-mt;

aiImportFileFromMemoryWithProperties :: (pBuffer: *s8, pLength: u32, pFlags: u32, pHint: *s8, pProps: *aiPropertyStore) -> *aiScene #foreign assimp-vc142-mt;

aiApplyPostProcessing :: (pScene: *aiScene, pFlags: u32) -> *aiScene #foreign assimp-vc142-mt;

aiGetPredefinedLogStream :: (pStreams: aiDefaultLogStream, file: *s8) -> aiLogStream #foreign assimp-vc142-mt;

aiAttachLogStream :: (stream: *aiLogStream) -> void #foreign assimp-vc142-mt;

aiEnableVerboseLogging :: (d: aiBool) -> void #foreign assimp-vc142-mt;

aiDetachLogStream :: (stream: *aiLogStream) -> aiReturn #foreign assimp-vc142-mt;

aiDetachAllLogStreams :: () -> void #foreign assimp-vc142-mt;

aiReleaseImport :: (pScene: *aiScene) -> void #foreign assimp-vc142-mt;

aiGetErrorString :: () -> *s8 #foreign assimp-vc142-mt;

aiIsExtensionSupported :: (szExtension: *s8) -> aiBool #foreign assimp-vc142-mt;

aiGetExtensionList :: (szOut: *aiString) -> void #foreign assimp-vc142-mt;

aiGetMemoryRequirements :: (pIn: *aiScene, in: *aiMemoryInfo) -> void #foreign assimp-vc142-mt;

aiCreatePropertyStore :: () -> *aiPropertyStore #foreign assimp-vc142-mt;

aiReleasePropertyStore :: (p: *aiPropertyStore) -> void #foreign assimp-vc142-mt;

aiSetImportPropertyInteger :: (store: *aiPropertyStore, szName: *s8, value: s32) -> void #foreign assimp-vc142-mt;

aiSetImportPropertyFloat :: (store: *aiPropertyStore, szName: *s8, value: ai_real) -> void #foreign assimp-vc142-mt;

aiSetImportPropertyString :: (store: *aiPropertyStore, szName: *s8, st: *aiString) -> void #foreign assimp-vc142-mt;

aiSetImportPropertyMatrix :: (store: *aiPropertyStore, szName: *s8, mat: *aiMatrix4x4) -> void #foreign assimp-vc142-mt;

aiCreateQuaternionFromMatrix :: (quat: *aiQuaternion, mat: *aiMatrix3x3) -> void #foreign assimp-vc142-mt;

aiDecomposeMatrix :: (mat: *aiMatrix4x4, scaling: *aiVector3D, rotation: *aiQuaternion, position: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiTransposeMatrix4 :: (mat: *aiMatrix4x4) -> void #foreign assimp-vc142-mt;

aiTransposeMatrix3 :: (mat: *aiMatrix3x3) -> void #foreign assimp-vc142-mt;

aiTransformVecByMatrix3 :: (vec: *aiVector3D, mat: *aiMatrix3x3) -> void #foreign assimp-vc142-mt;

aiTransformVecByMatrix4 :: (vec: *aiVector3D, mat: *aiMatrix4x4) -> void #foreign assimp-vc142-mt;

aiMultiplyMatrix4 :: (dst: *aiMatrix4x4, src: *aiMatrix4x4) -> void #foreign assimp-vc142-mt;

aiMultiplyMatrix3 :: (dst: *aiMatrix3x3, src: *aiMatrix3x3) -> void #foreign assimp-vc142-mt;

aiIdentityMatrix3 :: (mat: *aiMatrix3x3) -> void #foreign assimp-vc142-mt;

aiIdentityMatrix4 :: (mat: *aiMatrix4x4) -> void #foreign assimp-vc142-mt;

aiGetImportFormatCount :: () -> size_t #foreign assimp-vc142-mt;

aiGetImportFormatDescription :: (pIndex: size_t) -> *aiImporterDesc #foreign assimp-vc142-mt;

aiVector2AreEqual :: (a: *aiVector2D, b: *aiVector2D) -> s32 #foreign assimp-vc142-mt;

aiVector2AreEqualEpsilon :: (a: *aiVector2D, b: *aiVector2D, epsilon: float32) -> s32 #foreign assimp-vc142-mt;

aiVector2Add :: (dst: *aiVector2D, src: *aiVector2D) -> void #foreign assimp-vc142-mt;

aiVector2Subtract :: (dst: *aiVector2D, src: *aiVector2D) -> void #foreign assimp-vc142-mt;

aiVector2Scale :: (dst: *aiVector2D, s: float32) -> void #foreign assimp-vc142-mt;

aiVector2SymMul :: (dst: *aiVector2D, other: *aiVector2D) -> void #foreign assimp-vc142-mt;

aiVector2DivideByScalar :: (dst: *aiVector2D, s: float32) -> void #foreign assimp-vc142-mt;

aiVector2DivideByVector :: (dst: *aiVector2D, v: *aiVector2D) -> void #foreign assimp-vc142-mt;

aiVector2Length :: (v: *aiVector2D) -> float32 #foreign assimp-vc142-mt;

aiVector2SquareLength :: (v: *aiVector2D) -> float32 #foreign assimp-vc142-mt;

aiVector2Negate :: (dst: *aiVector2D) -> void #foreign assimp-vc142-mt;

aiVector2DotProduct :: (a: *aiVector2D, b: *aiVector2D) -> float32 #foreign assimp-vc142-mt;

aiVector2Normalize :: (v: *aiVector2D) -> void #foreign assimp-vc142-mt;

aiVector3AreEqual :: (a: *aiVector3D, b: *aiVector3D) -> s32 #foreign assimp-vc142-mt;

aiVector3AreEqualEpsilon :: (a: *aiVector3D, b: *aiVector3D, epsilon: float32) -> s32 #foreign assimp-vc142-mt;

aiVector3LessThan :: (a: *aiVector3D, b: *aiVector3D) -> s32 #foreign assimp-vc142-mt;

aiVector3Add :: (dst: *aiVector3D, src: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiVector3Subtract :: (dst: *aiVector3D, src: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiVector3Scale :: (dst: *aiVector3D, s: float32) -> void #foreign assimp-vc142-mt;

aiVector3SymMul :: (dst: *aiVector3D, other: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiVector3DivideByScalar :: (dst: *aiVector3D, s: float32) -> void #foreign assimp-vc142-mt;

aiVector3DivideByVector :: (dst: *aiVector3D, v: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiVector3Length :: (v: *aiVector3D) -> float32 #foreign assimp-vc142-mt;

aiVector3SquareLength :: (v: *aiVector3D) -> float32 #foreign assimp-vc142-mt;

aiVector3Negate :: (dst: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiVector3DotProduct :: (a: *aiVector3D, b: *aiVector3D) -> float32 #foreign assimp-vc142-mt;

aiVector3CrossProduct :: (dst: *aiVector3D, a: *aiVector3D, b: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiVector3Normalize :: (v: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiVector3NormalizeSafe :: (v: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiVector3RotateByQuaternion :: (v: *aiVector3D, q: *aiQuaternion) -> void #foreign assimp-vc142-mt;

aiMatrix3FromMatrix4 :: (dst: *aiMatrix3x3, mat: *aiMatrix4x4) -> void #foreign assimp-vc142-mt;

aiMatrix3FromQuaternion :: (mat: *aiMatrix3x3, q: *aiQuaternion) -> void #foreign assimp-vc142-mt;

aiMatrix3AreEqual :: (a: *aiMatrix3x3, b: *aiMatrix3x3) -> s32 #foreign assimp-vc142-mt;

aiMatrix3AreEqualEpsilon :: (a: *aiMatrix3x3, b: *aiMatrix3x3, epsilon: float32) -> s32 #foreign assimp-vc142-mt;

aiMatrix3Inverse :: (mat: *aiMatrix3x3) -> void #foreign assimp-vc142-mt;

aiMatrix3Determinant :: (mat: *aiMatrix3x3) -> float32 #foreign assimp-vc142-mt;

aiMatrix3RotationZ :: (mat: *aiMatrix3x3, angle: float32) -> void #foreign assimp-vc142-mt;

aiMatrix3FromRotationAroundAxis :: (mat: *aiMatrix3x3, axis: *aiVector3D, angle: float32) -> void #foreign assimp-vc142-mt;

aiMatrix3Translation :: (mat: *aiMatrix3x3, translation: *aiVector2D) -> void #foreign assimp-vc142-mt;

aiMatrix3FromTo :: (mat: *aiMatrix3x3, from: *aiVector3D, to: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiMatrix4FromMatrix3 :: (dst: *aiMatrix4x4, mat: *aiMatrix3x3) -> void #foreign assimp-vc142-mt;

aiMatrix4FromScalingQuaternionPosition :: (mat: *aiMatrix4x4, scaling: *aiVector3D, rotation: *aiQuaternion, position: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiMatrix4Add :: (dst: *aiMatrix4x4, src: *aiMatrix4x4) -> void #foreign assimp-vc142-mt;

aiMatrix4AreEqual :: (a: *aiMatrix4x4, b: *aiMatrix4x4) -> s32 #foreign assimp-vc142-mt;

aiMatrix4AreEqualEpsilon :: (a: *aiMatrix4x4, b: *aiMatrix4x4, epsilon: float32) -> s32 #foreign assimp-vc142-mt;

aiMatrix4Inverse :: (mat: *aiMatrix4x4) -> void #foreign assimp-vc142-mt;

aiMatrix4Determinant :: (mat: *aiMatrix4x4) -> float32 #foreign assimp-vc142-mt;

aiMatrix4IsIdentity :: (mat: *aiMatrix4x4) -> s32 #foreign assimp-vc142-mt;

aiMatrix4DecomposeIntoScalingEulerAnglesPosition :: (mat: *aiMatrix4x4, scaling: *aiVector3D, rotation: *aiVector3D, position: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiMatrix4DecomposeIntoScalingAxisAnglePosition :: (mat: *aiMatrix4x4, scaling: *aiVector3D, axis: *aiVector3D, angle: *ai_real, position: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiMatrix4DecomposeNoScaling :: (mat: *aiMatrix4x4, rotation: *aiQuaternion, position: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiMatrix4FromEulerAngles :: (mat: *aiMatrix4x4, x: float32, y: float32, z: float32) -> void #foreign assimp-vc142-mt;

aiMatrix4RotationX :: (mat: *aiMatrix4x4, angle: float32) -> void #foreign assimp-vc142-mt;

aiMatrix4RotationY :: (mat: *aiMatrix4x4, angle: float32) -> void #foreign assimp-vc142-mt;

aiMatrix4RotationZ :: (mat: *aiMatrix4x4, angle: float32) -> void #foreign assimp-vc142-mt;

aiMatrix4FromRotationAroundAxis :: (mat: *aiMatrix4x4, axis: *aiVector3D, angle: float32) -> void #foreign assimp-vc142-mt;

aiMatrix4Translation :: (mat: *aiMatrix4x4, translation: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiMatrix4Scaling :: (mat: *aiMatrix4x4, scaling: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiMatrix4FromTo :: (mat: *aiMatrix4x4, from: *aiVector3D, to: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiQuaternionFromEulerAngles :: (q: *aiQuaternion, x: float32, y: float32, z: float32) -> void #foreign assimp-vc142-mt;

aiQuaternionFromAxisAngle :: (q: *aiQuaternion, axis: *aiVector3D, angle: float32) -> void #foreign assimp-vc142-mt;

aiQuaternionFromNormalizedQuaternion :: (q: *aiQuaternion, normalized: *aiVector3D) -> void #foreign assimp-vc142-mt;

aiQuaternionAreEqual :: (a: *aiQuaternion, b: *aiQuaternion) -> s32 #foreign assimp-vc142-mt;

aiQuaternionAreEqualEpsilon :: (a: *aiQuaternion, b: *aiQuaternion, epsilon: float32) -> s32 #foreign assimp-vc142-mt;

aiQuaternionNormalize :: (q: *aiQuaternion) -> void #foreign assimp-vc142-mt;

aiQuaternionConjugate :: (q: *aiQuaternion) -> void #foreign assimp-vc142-mt;

aiQuaternionMultiply :: (dst: *aiQuaternion, q: *aiQuaternion) -> void #foreign assimp-vc142-mt;

aiQuaternionInterpolate :: (dst: *aiQuaternion, start: *aiQuaternion, end: *aiQuaternion, factor: float32) -> void #foreign assimp-vc142-mt;

