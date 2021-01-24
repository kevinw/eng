main :: () {
    skeleton: Skeleton;
    if !Sample.LoadSkeleton("media/skeleton.ozz", *skeleton)
        return;

    anim: Animation;
    if !Sample.LoadAnimation("media/animation.ozz", *anim)
        return;

    sampling_context: SamplingJob.Context;

    // Skeleton and animation needs to match.
    if skeleton.num_joints(*skeleton) != anim.num_tracks {
        print("error: skeleton num_joints % does not match animation num_tracks %\n",
            skeleton.num_joints, anim.num_tracks);
        return;
    }

    locals: [..]SoaTransform; // Buffer of local transforms as sampled from anim.
    models: [..]Float4x4;     // Buffer of model space matrices.

    // Allocates runtime buffers.
    num_soa_joints := skeleton.num_soa_joints(*skeleton);
    array_resize(*locals, num_soa_joints);
    num_joints := skeleton.num_joints(*skeleton);
    array_resize(*models, num_joints);

    // Allocates a context that matches animation requirements.
    sampling_context.Resize(*sampling_context, num_joints);

    controller: PlaybackController;
    
    // OnUpdate
    {
        dt:float = 1.0 / 60.0;
        update(*controller, *anim, dt);

        // Samples optimized animation at t = animation_time_.
        sampling_job: SamplingJob;
        sampling_job.animation = *anim;
        sampling_job.ctx = *sampling_context;
        sampling_job.ratio = controller.time_ratio;
        sampling_job.output = make_span(locals);
        if !sampling_job.Run(*sampling_job) {
            print("sampling job failed\n");
            return;
        }

        // Converts from local space to model space matrices.
        ltm_job: LocalToModelJob;
        ltm_job.skeleton = *skeleton;
        ltm_job.input = make_span(locals);
        ltm_job.output = make_span(models);
        if !ltm_job.Run(*ltm_job) {
            print("local to model job failed\n");
            return;
        }
    }

    // get scene bounds
    {
        bound: Box;
        Sample.ComputePostureBounds(make_span(models), *bound);
        print("posture bounds: %\n", bound);
    }
    {
        bound: Box;
        Sample.ComputeSkeletonBounds(*skeleton, *bound);
        print("skelton bounds: %\n", bound);
    }

    Sample.PrintSizes();
    print("Skeleton:\t% (jai)\n", size_of(Skeleton));
    print("Animation:\t% (jai)\n", size_of(Animation));
    print("SamplingJob.Context:\t% (jai)\n", size_of(SamplingJob.Context));

    print("OK\n");
}

#scope_file
#import "Basic";

#load "../module.jai";
