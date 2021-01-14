Particle_System :: struct {
    using component: Component;

    particles: [..]Particle; @noui @noserialize
}

Particle :: struct {
    position:  Vector3;
    velocity:  Vector3;
    radius:    float;
    color:     Vector4;
}

update :: (using particle_system: *Particle_System) {
    if particles.count == 0 {
        N :: 4000;
        array_resize(*particles, N);
        R01 :: random_get_zero_to_one;
        R   :: random_get_within_range;
        for * particles {
            it.position = make_vector3(R(0, 1000), R(-300, 700), R(-300, 1500));
            it.velocity = make_vector3(R01(), R01(), R01()) * 4;
            it.radius = R01() * 6;
            C :: 0.7;
            it.color = make_vector4(R01() * 0.1, R01() * 0.5, R01() * C, 1);
        }
    }

    Sort.quick_sort(particles, (p1, p2) => Sort.compare_floats(p1.position.z, p2.position.z));
}

draw :: (using particle_system: *Particle_System) {
    ctx := *context.state.im_context;

    t0 := make_vector2(0, 0);
    t1 := make_vector2(1, 1);

    t01 := xy(t0.x, t1.y);
    t10 := xy(t1.x, t0.y);

    im_set_texture(ctx, null);

    im_set_primitive(ctx, 3);
    im_ensure_space_for(ctx, index_count=6 * particles.count, vertex_count=4 * particles.count);

    for * particles {
        it.position += it.velocity * context.state.Time.delta_time;
        
        r2 := make_vector3(it.radius, it.radius, 0);
        p0 := (it.position - r2).xy;
        p1 := (it.position + r2).xy;

        p01 := xy(p0.x, p1.y);
        p10 := xy(p1.x, p0.y);

        im_set_z(ctx, it.position.z);
        c := it.color;
        c *= (300-it.position.z) / 300;

        v0 := im_vertex(ctx, p0, t0, c);
        v1 := im_vertex(ctx, p01, t01, c);
        v2 := im_vertex(ctx, p1, t1, c);
        v3 := im_vertex(ctx, p10, t10, c);

        im_indices(ctx, v0, v1, v2, v2, v0, v3);
    }
}

#scope_file
Sort :: #import "Sort";
#import "renderer_im";
#import "renderer_im_impl";
#import "Math";
#import "Basic";
#import "Random";
