uint32_t :: u32;
int32_t  :: s32;
size_t   :: s64;
assimp_vc142_mt :: #foreign_library "assimp-vc142-mt";
Component :: enum s32 {
    NORMALS :: 2;
    TANGENTS_AND_BITANGENTS :: 4;
    COLORS :: 8;
    TEXCOORDS :: 16;
    BONEWEIGHTS :: 32;
    ANIMATIONS :: 64;
    TEXTURES :: 128;
    LIGHTS :: 256;
    CAMERAS :: 512;
    MESHES :: 1024;
    MATERIALS :: 2048;
    _aiComponent_Force32Bit :: -1610612737;
}

ai_real :: float32;

ai_int :: s32;

ai_uint :: u32;

ai_epsilon: ai_real;

Vector2D :: struct {
    x: ai_real;
    y: ai_real;
}

Vector3D :: struct {
    x: ai_real;
    y: ai_real;
    z: ai_real;
}

Color4D :: struct {
    r: ai_real;
    g: ai_real;
    b: ai_real;
    a: ai_real;
}

Matrix3x3 :: struct {
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

Matrix4x4 :: struct {
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

Quaternion :: struct {
    w: ai_real;
    x: ai_real;
    y: ai_real;
    z: ai_real;
}

ai_int32 :: int32_t;

ai_uint32 :: uint32_t;

Plane :: struct {
    a: ai_real;
    b: ai_real;
    c: ai_real;
    d: ai_real;
}

Ray :: struct {
    pos: Vector3D;
    dir: Vector3D;
}

Color3D :: struct {
    r: ai_real;
    g: ai_real;
    b: ai_real;
}

String :: struct {
    length: ai_uint32;
    data: [1024] s8;
}

Return :: enum s32 {
    SUCCESS :: 0;
    FAILURE :: -1;
    OUTOFMEMORY :: -3;
}



Origin :: enum s32 {
    SET :: 0;
    CUR :: 1;
    END :: 2;
}

DefaultLogStream :: enum s32 {
    FILE :: 1;
    STDOUT :: 2;
    STDERR :: 4;
    DEBUGGER :: 8;
}

MemoryInfo :: struct {
    textures: u32;
    materials: u32;
    meshes: u32;
    nodes: u32;
    animations: u32;
    cameras: u32;
    lights: u32;
    total: u32;
}

ImporterFlags :: enum s32 {
    SupportTextFlavour :: 1;
    SupportBinaryFlavour :: 2;
    SupportCompressedFlavour :: 4;
    LimitedSupport :: 8;
    Experimental :: 16;
}

ImporterDesc :: struct {
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

GetImporterDesc :: (extension: *s8) -> *ImporterDesc #foreign assimp_vc142_mt "aiGetImporterDesc";

FileIO :: struct {
}

aiLogStreamCallback :: #type (a0: *s8, a1: *s8) -> void #c_call;

LogStream :: struct {
    callback: aiLogStreamCallback;
    user: *s8;
}

PropertyStore :: struct {
    sentinel: s8;
}

aiBool :: s32;

ImportFile :: (pFile: *s8, pFlags: u32) -> *Scene #foreign assimp_vc142_mt "aiImportFile";

ImportFileEx :: (pFile: *s8, pFlags: u32, pFS: *FileIO) -> *Scene #foreign assimp_vc142_mt "aiImportFileEx";

ImportFileExWithProperties :: (pFile: *s8, pFlags: u32, pFS: *FileIO, pProps: *PropertyStore) -> *Scene #foreign assimp_vc142_mt "aiImportFileExWithProperties";

ImportFileFromMemory :: (pBuffer: *s8, pLength: u32, pFlags: u32, pHint: *s8) -> *Scene #foreign assimp_vc142_mt "aiImportFileFromMemory";

ImportFileFromMemoryWithProperties :: (pBuffer: *s8, pLength: u32, pFlags: u32, pHint: *s8, pProps: *PropertyStore) -> *Scene #foreign assimp_vc142_mt "aiImportFileFromMemoryWithProperties";

ApplyPostProcessing :: (pScene: *Scene, pFlags: u32) -> *Scene #foreign assimp_vc142_mt "aiApplyPostProcessing";

GetPredefinedLogStream :: (pStreams: DefaultLogStream, file: *s8) -> LogStream #foreign assimp_vc142_mt "aiGetPredefinedLogStream";

AttachLogStream :: (stream: *LogStream) -> void #foreign assimp_vc142_mt "aiAttachLogStream";

EnableVerboseLogging :: (d: aiBool) -> void #foreign assimp_vc142_mt "aiEnableVerboseLogging";

DetachLogStream :: (stream: *LogStream) -> Return #foreign assimp_vc142_mt "aiDetachLogStream";

DetachAllLogStreams :: () -> void #foreign assimp_vc142_mt "aiDetachAllLogStreams";

ReleaseImport :: (pScene: *Scene) -> void #foreign assimp_vc142_mt "aiReleaseImport";

GetErrorString :: () -> *s8 #foreign assimp_vc142_mt "aiGetErrorString";

IsExtensionSupported :: (szExtension: *s8) -> aiBool #foreign assimp_vc142_mt "aiIsExtensionSupported";

GetExtensionList :: (szOut: *String) -> void #foreign assimp_vc142_mt "aiGetExtensionList";

GetMemoryRequirements :: (pIn: *Scene, in: *MemoryInfo) -> void #foreign assimp_vc142_mt "aiGetMemoryRequirements";

CreatePropertyStore :: () -> *PropertyStore #foreign assimp_vc142_mt "aiCreatePropertyStore";

ReleasePropertyStore :: (p: *PropertyStore) -> void #foreign assimp_vc142_mt "aiReleasePropertyStore";

SetImportPropertyInteger :: (store: *PropertyStore, szName: *s8, value: s32) -> void #foreign assimp_vc142_mt "aiSetImportPropertyInteger";

SetImportPropertyFloat :: (store: *PropertyStore, szName: *s8, value: ai_real) -> void #foreign assimp_vc142_mt "aiSetImportPropertyFloat";

SetImportPropertyString :: (store: *PropertyStore, szName: *s8, st: *String) -> void #foreign assimp_vc142_mt "aiSetImportPropertyString";

SetImportPropertyMatrix :: (store: *PropertyStore, szName: *s8, mat: *Matrix4x4) -> void #foreign assimp_vc142_mt "aiSetImportPropertyMatrix";

CreateQuaternionFromMatrix :: (quat: *Quaternion, mat: *Matrix3x3) -> void #foreign assimp_vc142_mt "aiCreateQuaternionFromMatrix";

DecomposeMatrix :: (mat: *Matrix4x4, scaling: *Vector3D, rotation: *Quaternion, position: *Vector3D) -> void #foreign assimp_vc142_mt "aiDecomposeMatrix";

TransposeMatrix4 :: (mat: *Matrix4x4) -> void #foreign assimp_vc142_mt "aiTransposeMatrix4";

TransposeMatrix3 :: (mat: *Matrix3x3) -> void #foreign assimp_vc142_mt "aiTransposeMatrix3";

TransformVecByMatrix3 :: (vec: *Vector3D, mat: *Matrix3x3) -> void #foreign assimp_vc142_mt "aiTransformVecByMatrix3";

TransformVecByMatrix4 :: (vec: *Vector3D, mat: *Matrix4x4) -> void #foreign assimp_vc142_mt "aiTransformVecByMatrix4";

MultiplyMatrix4 :: (dst: *Matrix4x4, src: *Matrix4x4) -> void #foreign assimp_vc142_mt "aiMultiplyMatrix4";

MultiplyMatrix3 :: (dst: *Matrix3x3, src: *Matrix3x3) -> void #foreign assimp_vc142_mt "aiMultiplyMatrix3";

IdentityMatrix3 :: (mat: *Matrix3x3) -> void #foreign assimp_vc142_mt "aiIdentityMatrix3";

IdentityMatrix4 :: (mat: *Matrix4x4) -> void #foreign assimp_vc142_mt "aiIdentityMatrix4";

GetImportFormatCount :: () -> size_t #foreign assimp_vc142_mt "aiGetImportFormatCount";

GetImportFormatDescription :: (pIndex: size_t) -> *ImporterDesc #foreign assimp_vc142_mt "aiGetImportFormatDescription";

Vector2AreEqual :: (a: *Vector2D, b: *Vector2D) -> s32 #foreign assimp_vc142_mt "aiVector2AreEqual";

Vector2AreEqualEpsilon :: (a: *Vector2D, b: *Vector2D, epsilon: float32) -> s32 #foreign assimp_vc142_mt "aiVector2AreEqualEpsilon";

Vector2Add :: (dst: *Vector2D, src: *Vector2D) -> void #foreign assimp_vc142_mt "aiVector2Add";

Vector2Subtract :: (dst: *Vector2D, src: *Vector2D) -> void #foreign assimp_vc142_mt "aiVector2Subtract";

Vector2Scale :: (dst: *Vector2D, s: float32) -> void #foreign assimp_vc142_mt "aiVector2Scale";

Vector2SymMul :: (dst: *Vector2D, other: *Vector2D) -> void #foreign assimp_vc142_mt "aiVector2SymMul";

Vector2DivideByScalar :: (dst: *Vector2D, s: float32) -> void #foreign assimp_vc142_mt "aiVector2DivideByScalar";

Vector2DivideByVector :: (dst: *Vector2D, v: *Vector2D) -> void #foreign assimp_vc142_mt "aiVector2DivideByVector";

Vector2Length :: (v: *Vector2D) -> float32 #foreign assimp_vc142_mt "aiVector2Length";

Vector2SquareLength :: (v: *Vector2D) -> float32 #foreign assimp_vc142_mt "aiVector2SquareLength";

Vector2Negate :: (dst: *Vector2D) -> void #foreign assimp_vc142_mt "aiVector2Negate";

Vector2DotProduct :: (a: *Vector2D, b: *Vector2D) -> float32 #foreign assimp_vc142_mt "aiVector2DotProduct";

Vector2Normalize :: (v: *Vector2D) -> void #foreign assimp_vc142_mt "aiVector2Normalize";

Vector3AreEqual :: (a: *Vector3D, b: *Vector3D) -> s32 #foreign assimp_vc142_mt "aiVector3AreEqual";

Vector3AreEqualEpsilon :: (a: *Vector3D, b: *Vector3D, epsilon: float32) -> s32 #foreign assimp_vc142_mt "aiVector3AreEqualEpsilon";

Vector3LessThan :: (a: *Vector3D, b: *Vector3D) -> s32 #foreign assimp_vc142_mt "aiVector3LessThan";

Vector3Add :: (dst: *Vector3D, src: *Vector3D) -> void #foreign assimp_vc142_mt "aiVector3Add";

Vector3Subtract :: (dst: *Vector3D, src: *Vector3D) -> void #foreign assimp_vc142_mt "aiVector3Subtract";

Vector3Scale :: (dst: *Vector3D, s: float32) -> void #foreign assimp_vc142_mt "aiVector3Scale";

Vector3SymMul :: (dst: *Vector3D, other: *Vector3D) -> void #foreign assimp_vc142_mt "aiVector3SymMul";

Vector3DivideByScalar :: (dst: *Vector3D, s: float32) -> void #foreign assimp_vc142_mt "aiVector3DivideByScalar";

Vector3DivideByVector :: (dst: *Vector3D, v: *Vector3D) -> void #foreign assimp_vc142_mt "aiVector3DivideByVector";

Vector3Length :: (v: *Vector3D) -> float32 #foreign assimp_vc142_mt "aiVector3Length";

Vector3SquareLength :: (v: *Vector3D) -> float32 #foreign assimp_vc142_mt "aiVector3SquareLength";

Vector3Negate :: (dst: *Vector3D) -> void #foreign assimp_vc142_mt "aiVector3Negate";

Vector3DotProduct :: (a: *Vector3D, b: *Vector3D) -> float32 #foreign assimp_vc142_mt "aiVector3DotProduct";

Vector3CrossProduct :: (dst: *Vector3D, a: *Vector3D, b: *Vector3D) -> void #foreign assimp_vc142_mt "aiVector3CrossProduct";

Vector3Normalize :: (v: *Vector3D) -> void #foreign assimp_vc142_mt "aiVector3Normalize";

Vector3NormalizeSafe :: (v: *Vector3D) -> void #foreign assimp_vc142_mt "aiVector3NormalizeSafe";

Vector3RotateByQuaternion :: (v: *Vector3D, q: *Quaternion) -> void #foreign assimp_vc142_mt "aiVector3RotateByQuaternion";

Matrix3FromMatrix4 :: (dst: *Matrix3x3, mat: *Matrix4x4) -> void #foreign assimp_vc142_mt "aiMatrix3FromMatrix4";

Matrix3FromQuaternion :: (mat: *Matrix3x3, q: *Quaternion) -> void #foreign assimp_vc142_mt "aiMatrix3FromQuaternion";

Matrix3AreEqual :: (a: *Matrix3x3, b: *Matrix3x3) -> s32 #foreign assimp_vc142_mt "aiMatrix3AreEqual";

Matrix3AreEqualEpsilon :: (a: *Matrix3x3, b: *Matrix3x3, epsilon: float32) -> s32 #foreign assimp_vc142_mt "aiMatrix3AreEqualEpsilon";

Matrix3Inverse :: (mat: *Matrix3x3) -> void #foreign assimp_vc142_mt "aiMatrix3Inverse";

Matrix3Determinant :: (mat: *Matrix3x3) -> float32 #foreign assimp_vc142_mt "aiMatrix3Determinant";

Matrix3RotationZ :: (mat: *Matrix3x3, angle: float32) -> void #foreign assimp_vc142_mt "aiMatrix3RotationZ";

Matrix3FromRotationAroundAxis :: (mat: *Matrix3x3, axis: *Vector3D, angle: float32) -> void #foreign assimp_vc142_mt "aiMatrix3FromRotationAroundAxis";

Matrix3Translation :: (mat: *Matrix3x3, translation: *Vector2D) -> void #foreign assimp_vc142_mt "aiMatrix3Translation";

Matrix3FromTo :: (mat: *Matrix3x3, from: *Vector3D, to: *Vector3D) -> void #foreign assimp_vc142_mt "aiMatrix3FromTo";

Matrix4FromMatrix3 :: (dst: *Matrix4x4, mat: *Matrix3x3) -> void #foreign assimp_vc142_mt "aiMatrix4FromMatrix3";

Matrix4FromScalingQuaternionPosition :: (mat: *Matrix4x4, scaling: *Vector3D, rotation: *Quaternion, position: *Vector3D) -> void #foreign assimp_vc142_mt "aiMatrix4FromScalingQuaternionPosition";

Matrix4Add :: (dst: *Matrix4x4, src: *Matrix4x4) -> void #foreign assimp_vc142_mt "aiMatrix4Add";

Matrix4AreEqual :: (a: *Matrix4x4, b: *Matrix4x4) -> s32 #foreign assimp_vc142_mt "aiMatrix4AreEqual";

Matrix4AreEqualEpsilon :: (a: *Matrix4x4, b: *Matrix4x4, epsilon: float32) -> s32 #foreign assimp_vc142_mt "aiMatrix4AreEqualEpsilon";

Matrix4Inverse :: (mat: *Matrix4x4) -> void #foreign assimp_vc142_mt "aiMatrix4Inverse";

Matrix4Determinant :: (mat: *Matrix4x4) -> float32 #foreign assimp_vc142_mt "aiMatrix4Determinant";

Matrix4IsIdentity :: (mat: *Matrix4x4) -> s32 #foreign assimp_vc142_mt "aiMatrix4IsIdentity";

Matrix4DecomposeIntoScalingEulerAnglesPosition :: (mat: *Matrix4x4, scaling: *Vector3D, rotation: *Vector3D, position: *Vector3D) -> void #foreign assimp_vc142_mt "aiMatrix4DecomposeIntoScalingEulerAnglesPosition";

Matrix4DecomposeIntoScalingAxisAnglePosition :: (mat: *Matrix4x4, scaling: *Vector3D, axis: *Vector3D, angle: *ai_real, position: *Vector3D) -> void #foreign assimp_vc142_mt "aiMatrix4DecomposeIntoScalingAxisAnglePosition";

Matrix4DecomposeNoScaling :: (mat: *Matrix4x4, rotation: *Quaternion, position: *Vector3D) -> void #foreign assimp_vc142_mt "aiMatrix4DecomposeNoScaling";

Matrix4FromEulerAngles :: (mat: *Matrix4x4, x: float32, y: float32, z: float32) -> void #foreign assimp_vc142_mt "aiMatrix4FromEulerAngles";

Matrix4RotationX :: (mat: *Matrix4x4, angle: float32) -> void #foreign assimp_vc142_mt "aiMatrix4RotationX";

Matrix4RotationY :: (mat: *Matrix4x4, angle: float32) -> void #foreign assimp_vc142_mt "aiMatrix4RotationY";

Matrix4RotationZ :: (mat: *Matrix4x4, angle: float32) -> void #foreign assimp_vc142_mt "aiMatrix4RotationZ";

Matrix4FromRotationAroundAxis :: (mat: *Matrix4x4, axis: *Vector3D, angle: float32) -> void #foreign assimp_vc142_mt "aiMatrix4FromRotationAroundAxis";

Matrix4Translation :: (mat: *Matrix4x4, translation: *Vector3D) -> void #foreign assimp_vc142_mt "aiMatrix4Translation";

Matrix4Scaling :: (mat: *Matrix4x4, scaling: *Vector3D) -> void #foreign assimp_vc142_mt "aiMatrix4Scaling";

Matrix4FromTo :: (mat: *Matrix4x4, from: *Vector3D, to: *Vector3D) -> void #foreign assimp_vc142_mt "aiMatrix4FromTo";

QuaternionFromEulerAngles :: (q: *Quaternion, x: float32, y: float32, z: float32) -> void #foreign assimp_vc142_mt "aiQuaternionFromEulerAngles";

QuaternionFromAxisAngle :: (q: *Quaternion, axis: *Vector3D, angle: float32) -> void #foreign assimp_vc142_mt "aiQuaternionFromAxisAngle";

QuaternionFromNormalizedQuaternion :: (q: *Quaternion, normalized: *Vector3D) -> void #foreign assimp_vc142_mt "aiQuaternionFromNormalizedQuaternion";

QuaternionAreEqual :: (a: *Quaternion, b: *Quaternion) -> s32 #foreign assimp_vc142_mt "aiQuaternionAreEqual";

QuaternionAreEqualEpsilon :: (a: *Quaternion, b: *Quaternion, epsilon: float32) -> s32 #foreign assimp_vc142_mt "aiQuaternionAreEqualEpsilon";

QuaternionNormalize :: (q: *Quaternion) -> void #foreign assimp_vc142_mt "aiQuaternionNormalize";

QuaternionConjugate :: (q: *Quaternion) -> void #foreign assimp_vc142_mt "aiQuaternionConjugate";

QuaternionMultiply :: (dst: *Quaternion, q: *Quaternion) -> void #foreign assimp_vc142_mt "aiQuaternionMultiply";

QuaternionInterpolate :: (dst: *Quaternion, start: *Quaternion, end: *Quaternion, factor: float32) -> void #foreign assimp_vc142_mt "aiQuaternionInterpolate";

PostProcessSteps :: enum s32 {
    CalcTangentSpace :: 1;
    JoinIdenticalVertices :: 2;
    MakeLeftHanded :: 4;
    Triangulate :: 8;
    RemoveComponent :: 16;
    GenNormals :: 32;
    GenSmoothNormals :: 64;
    SplitLargeMeshes :: 128;
    PreTransformVertices :: 256;
    LimitBoneWeights :: 512;
    ValidateDataStructure :: 1024;
    ImproveCacheLocality :: 2048;
    RemoveRedundantMaterials :: 4096;
    FixInfacingNormals :: 8192;
    PopulateArmatureData :: 16384;
    SortByPType :: 32768;
    FindDegenerates :: 65536;
    FindInvalidData :: 131072;
    GenUVCoords :: 262144;
    TransformUVCoords :: 524288;
    FindInstances :: 1048576;
    OptimizeMeshes :: 2097152;
    OptimizeGraph :: 4194304;
    FlipUVs :: 8388608;
    FlipWindingOrder :: 16777216;
    SplitByBoneCount :: 33554432;
    Debone :: 67108864;
    GlobalScale :: 134217728;
    EmbedTextures :: 268435456;
    ForceGenNormals :: 536870912;
    DropNormals :: 1073741824;
    GenBoundingBoxes :: -2147483648;
}

Texel :: struct {
    b: u8;
    g: u8;
    r: u8;
    a: u8;
}

Texture :: struct {
    mWidth: u32;
    mHeight: u32;
    achFormatHint: [9] s8;
    pcData: *Texel;
    mFilename: String;
}

AABB :: struct {
    mMin: Vector3D;
    mMax: Vector3D;
}

Face :: struct {
    mNumIndices: u32;
    mIndices: *u32;
}

VertexWeight :: struct {
    mVertexId: u32;
    mWeight: ai_real;
}

Bone :: struct {
    mName: String;
    mNumWeights: u32;
    mArmature: *Node;
    mNode: *Node;
    mWeights: *VertexWeight;
    mOffsetMatrix: Matrix4x4;
}

PrimitiveType :: enum s32 {
    POINT :: 1;
    LINE :: 2;
    TRIANGLE :: 4;
    POLYGON :: 8;
    _aiPrimitiveType_Force32Bit :: 2147483647;
}

AnimMesh :: struct {
    mName: String;
    mVertices: *Vector3D;
    mNormals: *Vector3D;
    mTangents: *Vector3D;
    mBitangents: *Vector3D;
    mColors: [8] *Color4D;
    mTextureCoords: [8] *Vector3D;
    mNumVertices: u32;
    mWeight: float32;
}

MorphingMethod :: enum s32 {
    VERTEX_BLEND :: 1;
    MORPH_NORMALIZED :: 2;
    MORPH_RELATIVE :: 3;
    _aiMorphingMethod_Force32Bit :: 2147483647;
}

Mesh :: struct {
    mPrimitiveTypes: u32;
    mNumVertices: u32;
    mNumFaces: u32;
    mVertices: *Vector3D;
    mNormals: *Vector3D;
    mTangents: *Vector3D;
    mBitangents: *Vector3D;
    mColors: [8] *Color4D;
    mTextureCoords: [8] *Vector3D;
    mNumUVComponents: [8] u32;
    mFaces: *Face;
    mNumBones: u32;
    mBones: **Bone;
    mMaterialIndex: u32;
    mName: String;
    mNumAnimMeshes: u32;
    mAnimMeshes: **AnimMesh;
    mMethod: u32;
    mAABB: AABB;
}

LightSourceType :: enum s32 {
    aiLightSource_UNDEFINED :: 0;
    aiLightSource_DIRECTIONAL :: 1;
    aiLightSource_POINT :: 2;
    aiLightSource_SPOT :: 3;
    aiLightSource_AMBIENT :: 4;
    aiLightSource_AREA :: 5;
    _aiLightSource_Force32Bit :: 2147483647;
}

Light :: struct {
    mName: String;
    mType: LightSourceType;
    mPosition: Vector3D;
    mDirection: Vector3D;
    mUp: Vector3D;
    mAttenuationConstant: float32;
    mAttenuationLinear: float32;
    mAttenuationQuadratic: float32;
    mColorDiffuse: Color3D;
    mColorSpecular: Color3D;
    mColorAmbient: Color3D;
    mAngleInnerCone: float32;
    mAngleOuterCone: float32;
    mSize: Vector2D;
}

Camera :: struct {
    mName: String;
    mPosition: Vector3D;
    mUp: Vector3D;
    mLookAt: Vector3D;
    mHorizontalFOV: float32;
    mClipPlaneNear: float32;
    mClipPlaneFar: float32;
    mAspect: float32;
    mOrthographicWidth: float32;
}

TextureOp :: enum s32 {
    Multiply :: 0;
    Add :: 1;
    Subtract :: 2;
    Divide :: 3;
    SmoothAdd :: 4;
    SignedAdd :: 5;
    _aiTextureOp_Force32Bit :: 2147483647;
}

TextureMapMode :: enum s32 {
    Wrap :: 0;
    Clamp :: 1;
    Decal :: 3;
    Mirror :: 2;
    _aiTextureMapMode_Force32Bit :: 2147483647;
}

TextureMapping :: enum s32 {
    UV :: 0;
    SPHERE :: 1;
    CYLINDER :: 2;
    BOX :: 3;
    PLANE :: 4;
    OTHER :: 5;
    _aiTextureMapping_Force32Bit :: 2147483647;
}

TextureType :: enum s32 {
    NONE :: 0;
    DIFFUSE :: 1;
    SPECULAR :: 2;
    AMBIENT :: 3;
    EMISSIVE :: 4;
    HEIGHT :: 5;
    NORMALS :: 6;
    SHININESS :: 7;
    OPACITY :: 8;
    DISPLACEMENT :: 9;
    LIGHTMAP :: 10;
    REFLECTION :: 11;
    BASE_COLOR :: 12;
    NORMAL_CAMERA :: 13;
    EMISSION_COLOR :: 14;
    METALNESS :: 15;
    DIFFUSE_ROUGHNESS :: 16;
    AMBIENT_OCCLUSION :: 17;
    UNKNOWN :: 18;
    _aiTextureType_Force32Bit :: 2147483647;
}

xtureTypeToString :: (in: TextureType) -> *s8 #foreign assimp_vc142_mt "TextureTypeToString";

ShadingMode :: enum s32 {
    Flat :: 1;
    Gouraud :: 2;
    Phong :: 3;
    Blinn :: 4;
    Toon :: 5;
    OrenNayar :: 6;
    Minnaert :: 7;
    CookTorrance :: 8;
    NoShading :: 9;
    Fresnel :: 10;
    _aiShadingMode_Force32Bit :: 2147483647;
}

TextureFlags :: enum s32 {
    Invert :: 1;
    UseAlpha :: 2;
    IgnoreAlpha :: 4;
    _aiTextureFlags_Force32Bit :: 2147483647;
}

BlendMode :: enum s32 {
    Default :: 0;
    Additive :: 1;
    _aiBlendMode_Force32Bit :: 2147483647;
}

UVTransform :: struct {
    mTranslation: Vector2D;
    mScaling: Vector2D;
    mRotation: ai_real;
}

PropertyTypeInfo :: enum s32 {
    aiPTI_Float :: 1;
    aiPTI_Double :: 2;
    aiPTI_String :: 3;
    aiPTI_Integer :: 4;
    aiPTI_Buffer :: 5;
    _aiPTI_Force32Bit :: 2147483647;
}

MaterialProperty :: struct {
    mKey: String;
    mSemantic: u32;
    mIndex: u32;
    mDataLength: u32;
    mType: PropertyTypeInfo;
    mData: *s8;
}

Material :: struct {
    mProperties: **MaterialProperty;
    mNumProperties: u32;
    mNumAllocated: u32;
}

GetMaterialProperty :: (pMat: *Material, pKey: *s8, type: u32, index: u32, pPropOut: **MaterialProperty) -> Return #foreign assimp_vc142_mt "aiGetMaterialProperty";

GetMaterialFloatArray :: (pMat: *Material, pKey: *s8, type: u32, index: u32, pOut: *ai_real, pMax: *u32) -> Return #foreign assimp_vc142_mt "aiGetMaterialFloatArray";

GetMaterialIntegerArray :: (pMat: *Material, pKey: *s8, type: u32, index: u32, pOut: *s32, pMax: *u32) -> Return #foreign assimp_vc142_mt "aiGetMaterialIntegerArray";

GetMaterialColor :: (pMat: *Material, pKey: *s8, type: u32, index: u32, pOut: *Color4D) -> Return #foreign assimp_vc142_mt "aiGetMaterialColor";

GetMaterialUVTransform :: (pMat: *Material, pKey: *s8, type: u32, index: u32, pOut: *UVTransform) -> Return #foreign assimp_vc142_mt "aiGetMaterialUVTransform";

GetMaterialString :: (pMat: *Material, pKey: *s8, type: u32, index: u32, pOut: *String) -> Return #foreign assimp_vc142_mt "aiGetMaterialString";

GetMaterialTextureCount :: (pMat: *Material, type: TextureType) -> u32 #foreign assimp_vc142_mt "aiGetMaterialTextureCount";

GetMaterialTexture :: (mat: *Material, type: TextureType, index: u32, path: *String, mapping: *TextureMapping, uvindex: *u32, blend: *ai_real, op: *TextureOp, mapmode: *TextureMapMode, flags: *u32) -> Return #foreign assimp_vc142_mt "aiGetMaterialTexture";

VectorKey :: struct {
    mTime: float64;
    mValue: Vector3D;
}

QuatKey :: struct {
    mTime: float64;
    mValue: Quaternion;
}

MeshKey :: struct {
    mTime: float64;
    mValue: u32;
}

MeshMorphKey :: struct {
    mTime: float64;
    mValues: *u32;
    mWeights: *float64;
    mNumValuesAndWeights: u32;
}

AnimBehaviour :: enum s32 {
    DEFAULT :: 0;
    CONSTANT :: 1;
    LINEAR :: 2;
    REPEAT :: 3;
    _aiAnimBehaviour_Force32Bit :: 2147483647;
}

NodeAnim :: struct {
    mNodeName: String;
    mNumPositionKeys: u32;
    mPositionKeys: *VectorKey;
    mNumRotationKeys: u32;
    mRotationKeys: *QuatKey;
    mNumScalingKeys: u32;
    mScalingKeys: *VectorKey;
    mPreState: AnimBehaviour;
    mPostState: AnimBehaviour;
}

MeshAnim :: struct {
    mName: String;
    mNumKeys: u32;
    mKeys: *MeshKey;
}

MeshMorphAnim :: struct {
    mName: String;
    mNumKeys: u32;
    mKeys: *MeshMorphKey;
}

Animation :: struct {
    mName: String;
    mDuration: float64;
    mTicksPerSecond: float64;
    mNumChannels: u32;
    mChannels: **NodeAnim;
    mNumMeshChannels: u32;
    mMeshChannels: **MeshAnim;
    mNumMorphMeshChannels: u32;
    mMorphMeshChannels: **MeshMorphAnim;
}

MetadataType :: enum s32 {
    AI_BOOL :: 0;
    AI_INT32 :: 1;
    AI_UINT64 :: 2;
    AI_FLOAT :: 3;
    AI_DOUBLE :: 4;
    AI_AISTRING :: 5;
    AI_AIVECTOR3D :: 6;
    AI_AIMETADATA :: 7;
    AI_META_MAX :: 8;
    FORCE_32BIT :: 2147483647;
}



MetadataEntry :: struct {
    mType: aiMetadataType;
    mData: *void;
}

Metadata :: struct {
    mNumProperties: u32;
    mKeys: *String;
    mValues: *MetadataEntry;
}

Node :: struct {
    mName: String;
    mTransformation: Matrix4x4;
    mParent: *Node;
    mNumChildren: u32;
    mChildren: **Node;
    mNumMeshes: u32;
    mMeshes: *u32;
    mMetaData: *Metadata;
}

Scene :: struct {
    mFlags: u32;
    mRootNode: *Node;
    mNumMeshes: u32;
    mMeshes: **Mesh;
    mNumMaterials: u32;
    mMaterials: **Material;
    mNumAnimations: u32;
    mAnimations: **Animation;
    mNumTextures: u32;
    mTextures: **Texture;
    mNumLights: u32;
    mLights: **Light;
    mNumCameras: u32;
    mCameras: **Camera;
    mMetaData: *Metadata;
    mName: String;
    mPrivate: *s8;
}

