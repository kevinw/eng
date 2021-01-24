Span :: struct(T: Type) {
    data: *T;
    size: int;
}

make_span :: (array_view: []$T) -> Span(T) {
    span: Span(T);
    span.data = array_view.data;
    span.size = array_view.count;
    return span;
}

Float3 :: Vector3;

SimdFloat4 :: Vector4;

SoaQuaternion :: struct { x, y, z, w: SimdFloat4; }
SoaFloat2 :: struct { x, y: SimdFloat4; }
SoaFloat3 :: struct { x, y, z: SimdFloat4; }
SoaFloat4 :: struct { x, y, z, w: SimdFloat4; }
Float4x4 :: Matrix4;


SoaTransform :: struct {
    translation: SoaFloat3;
    rotation:    SoaQuaternion;
    scale:       SoaFloat3;
}

Box :: struct {
    min: Float3;
    max: Float3;
}

Skeleton :: struct {
    Constants :: enum {
        kMaxJoints    :: 1024;
        kMaxSoAJoints :: (cast(int)kMaxJoints + 3) / 4;
        kNoParent     :: -1;
    }

    // Buffers below store joint informations in joing depth first order. Their
    // size is equal to the number of joints of the skeleton.

    // Bind pose of every joint in local space.
    joint_bind_poses: Span(SoaTransform);

    // Array of joint parent indexes.
    joint_parents:    Span(s16);

    // Stores the name of every joint in an array of c-strings.
    joint_names:      Span(*u8);
    
    num_joints     :: (using it: *Skeleton) -> s32 { return cast(s32)joint_parents.size; }
    num_soa_joints :: (using it: *Skeleton) -> s32 { return (num_joints(it) + 3) / 4; }
}

Sample :: struct {
    LoadSkeleton  :: (filename: *u8, skeleton: *Skeleton)   -> bool #foreign ozz_samples_framework "?LoadSkeleton@sample@ozz@@YA_NPEBDPEAVSkeleton@animation@2@@Z";
    LoadAnimation :: (filename: *u8, animation: *Animation) -> bool #foreign ozz_samples_framework "?LoadAnimation@sample@ozz@@YA_NPEBDPEAVAnimation@animation@2@@Z"
    PrintSizes    :: ()                                             #foreign ozz_samples_framework "?PrintSizes@sample@ozz@@YAXXZ"
    ComputePostureBounds :: (matrices: Span(Float4x4), bound: *Box) #foreign ozz_samples_framework "?ComputePostureBounds@sample@ozz@@YAXU?$span@$$CBUFloat4x4@math@ozz@@@2@PEAUBox@math@2@@Z";
    ComputeSkeletonBounds :: (skeleton: *Skeleton, bound: *Box)     #foreign ozz_samples_framework "?ComputeSkeletonBounds@sample@ozz@@YAXAEBVSkeleton@animation@2@PEAUBox@math@2@@Z";
}

Float3Key :: struct {
    ratio: float;
    track: u16;
    value: [3]u16;
}

QuaternionKey :: struct {
    ratio: float;
    //uint16_t track : 13;   // The track this key frame belongs to.
    //uint16_t largest : 2;  // The largest component of the quaternion.
    //uint16_t sign : 1;     // The sign of the largest component. 1 for negative.
    track_largest_sign: u16;
    value: [3]s16;
}

SamplingCache :: struct {
    animation: *Animation;
    ratio:     float;
    max_soa_tracks: s32;
}

SamplingJob :: struct {
    // Time ratio in the unit interval [0,1] used to sample animation (where 0 is
    // the beginning of the animation, 1 is the end). It should be computed as the
    // current time in the animation , divided by animation duration.
    // This ratio is clamped before job execution in order to resolves any
    // approximation issue on range bounds.
    ratio: float;

    // The animation to sample.
    animation: *Animation;

    // A context object that must be big enough to sample *this animation.
    ctx: *SamplingJob.Context;

    // Job output.
    // The output range to be filled with sampled joints during job execution.
    // If there are less joints in the animation compared to the output range,
    // then remaining SoaTransform are left unchanged.
    // If there are more joints in the animation, then the last joints are not
    // sampled.
    output: Span(SoaTransform);

    // FUNCS

    Run :: (job: *SamplingJob) -> bool #foreign ozz_samples_framework "?Run@SamplingJob@animation@ozz@@QEBA_NXZ";

    Context :: struct {
        // The animation this context refers to. nullptr means that the context is
        // invalid.
        animation: *Animation;

        // The current time ratio in the animation.
        ratio: float;

        // The number of soa tracks that can store this context.
        max_soa_tracks: s32;

        // Soa hot data to interpolate.
        soa_translations_: *InterpSoaFloat3;
        soa_rotations_:    *InterpSoaQuaternion;
        soa_scales_:       *InterpSoaFloat3;

        // Points to the keys in the animation that are valid for the current time
        // ratio.
        translation_keys_: *s32;
        rotation_keys_:    *s32;
        scale_keys_:       *s32;

        // Current cursors in the animation. 0 means that the context is invalid.
        translation_cursor_: s32;
        rotation_cursor_:    s32;
        scale_cursor_:       s32;

        // Outdated soa entries. One bit per soa entry (32 joints per byte).
        outdated_translations_: *u8;
        outdated_rotations_:    *u8;
        outdated_scales_:       *u8;
        
        // FUNCS
        
        // Resize the number of joints that the context can support.
        // This also implicitly invalidate the context.
        Resize :: (ctx: *Context, max_tracks: s32) #foreign ozz_samples_framework "_SamplingJob_Context_Resize";
    }
}

LocalToModelJob :: struct {
    // Job input.
  
    // The Skeleton object describing the joint hierarchy used for local to
    // model space conversion.
    skeleton: *Skeleton;
  
    // The root matrix will multiply to every model space matrices, default nullptr
    // means an identity matrix. This can be used to directly compute world-space
    // transforms for example.
    root: *Float4x4;
  
    // Defines "from" which joint the local-to-model conversion should start.
    // Default value is ozz::Skeleton::kNoParent, meaning the whole hierarchy is
    // updated. This parameter can be used to optimize update by limiting
    // conversion to part of the joint hierarchy. Note that "from" parent should
    // be a valid matrix, as it is going to be used as part of "from" joint
    // hierarchy update.
    from: s32;
  
    // Defines "to" which joint the local-to-model conversion should go, "to"
    // included. Update will end before "to" joint is reached if "to" is not part
    // of the hierarchy starting from "from". Default value is
    // ozz::animation::Skeleton::kMaxJoints, meaning the hierarchy (starting from
    // "from") is updated to the last joint.
    to: s32;
  
    // If true, "from" joint is not updated during job execution. Update starts
    // with all children of "from". This can be used to update a model-space
    // transform independently from the local-space one. To do so: set "from"
    // joint model-space transform matrix, and run this Job with "from_excluded"
    // to update all "from" children.
    // Default value is false.
    from_excluded: bool;
  
    // The input range that store local transforms.
    input: Span(SoaTransform);
  
    // Job output.
  
    // The output range to be filled with model-space matrices.
    output: Span(Float4x4);
  
    Run :: (job: *LocalToModelJob) -> bool #foreign ozz_animation "?Run@LocalToModelJob@animation@ozz@@QEBA_NXZ";
}

InterpSoaFloat3 :: struct {
    ratio: [2]SimdFloat4;
    value: [2]SoaFloat3;
}

InterpSoaQuaternion :: struct {
    ratio: [2]SimdFloat4;
    value: [2]SoaQuaternion;
};

Animation :: struct {
    duration:   float;
    num_tracks: s32;
    name:       *u8;

    translations: Span(Float3Key);
    rotations:    Span(QuaternionKey);
    scales:       Span(Float3Key);
}

//// 


// TODO: from the samples...not sure this should be in the bindings layer

PlaybackController :: struct {
  // Current animation time ratio, in the unit interval [0,1], where 0 is the
  // beginning of the animation, 1 is the end.
  time_ratio: float;

  // Time ratio of the previous update.
  previous_time_ratio: float;

  // Playback speed, can be negative in order to play the animation backward.
  playback_speed: float;

  // Animation play mode state: play/pause.
  play: bool;

  // Animation loop mode.
  loop: bool;
}

update :: (using it: *PlaybackController, animation: *Animation, dt: float) {
    new_time := time_ratio;

    if play
        new_time = time_ratio + dt * playback_speed / animation.duration;

    // Must be called even if time doesn't change, in order to update previous
    // frame time ratio. Uses set_time_ratio function in order to update
    // previous_time_ an wrap time value in the unit interval (depending on loop
    // mode).
    set_time_ratio(it, new_time);
}

set_time_ratio :: (using it: *PlaybackController, ratio: float) {
  previous_time_ratio = time_ratio;
  if loop {
    // Wraps in the unit interval [0:1], even for negative values (the reason
    // for using floorf).
    time_ratio = ratio - floor(ratio);
  } else {
    // Clamps in the unit interval [0:1].
    time_ratio = clamp(ratio, 0, 1);
  }
}

reset :: (using it: *PlaybackController) {
    assert(false);
}

////
    
#scope_file
#import "Math";

ozz_animation         :: #foreign_library,no_dll "lib/win/release/ozz_animation_r";
ozz_animation_offline :: #foreign_library,no_dll "lib/win/release/ozz_animation_offline_r";
ozz_base              :: #foreign_library,no_dll "lib/win/release/ozz_base_r";
ozz_geometry          :: #foreign_library,no_dll "lib/win/release/ozz_geometry_r";
ozz_options           :: #foreign_library,no_dll "lib/win/release/ozz_options_r";
ozz_samples_framework :: #foreign_library,no_dll "lib/win/release/sample_framework_r";
