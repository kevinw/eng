main :: () {
    window_width  :: 1280;
    window_height :: 720;
    title :: "render example";

    the_window := create_window(window_width, window_height, title);

    renderer: Renderer;
    init(*renderer, the_window);
    device := renderer.device;
    device_context1 := renderer.device_context1;
    shader_ok, shader := load_shader_from_file(*renderer, "shaders.hlsl");
    assert(shader_ok);

    pipeline := make_pipeline(*shader, .Triangles);

    // constant buffer
    Constants :: struct {
        Transform: Matrix4;
        Projection: Matrix4;
        LightVector: Vector3;
    };

    constant_buffer := create_constant_buffer(Constants);
    vertex_buffer   := create_immutable_buffer(VertexData, .Vertex);
    index_buffer    := create_immutable_buffer(IndexData, .Index);
    tex_ok, texture := load_texture_from_data(*renderer, TEXTURE_WIDTH, TEXTURE_HEIGHT, 4, TextureData.data);
    assert(tex_ok);

    // setup

    w := cast(float)renderer.depth_buffer_desc.Width;  // width
    h := cast(float)renderer.depth_buffer_desc.Height; // height
    n :float = 1000;                                    // near
    f :float = 1000000;                                 // far

    modelRotation    := Vector3.{ 0, 0, 0 };
    modelScale       := Vector3.{ 400.0, 400.0, 400.0 };
    modelTranslation := Vector3.{ 0.0, 0.0, 1500.0 };

    // main loop
    elapsed_time: float64;
    last_time: float64;
    dt: float;
    quit := false;
    while !quit {
        update_window_events();
        for events_this_frame {
            if it.type == {
                case .QUIT;
                    quit = true;
                case .KEYBOARD;
                    if it.key_pressed && (it.key_code == .ESCAPE)
                        quit = true;
            }
        }

        now := get_time();
        if last_time dt = cast(float) (now - last_time);
        last_time = now;
        
        elapsed_time += dt;

        // UPDATE
        rotateX   := make_matrix4(1, 0, 0, 0, 0, cos(modelRotation.x), -sin(modelRotation.x), 0, 0, sin(modelRotation.x), cos(modelRotation.x), 0, 0, 0, 0, 1 );
        rotateY   := make_matrix4(cos(modelRotation.y), 0, sin(modelRotation.y), 0, 0, 1, 0, 0, -sin(modelRotation.y), 0, cos(modelRotation.y), 0, 0, 0, 0, 1 );
        rotateZ   := make_matrix4(cos(modelRotation.z), -sin(modelRotation.z), 0, 0, sin(modelRotation.z), cos(modelRotation.z), 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 );
        scale     := make_matrix4(modelScale.x, 0, 0, 0, 0, modelScale.y, 0, 0, 0, 0, modelScale.z, 0, 0, 0, 0, 1 );
        translate := make_matrix4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, modelTranslation.x, modelTranslation.y, modelTranslation.z, 1 );

        modelRotation.x += 0.5 * dt;
        modelRotation.y += 0.9 * dt;
        modelRotation.z += 0.1 * dt;
        // END UPDATE

        reset_temporary_storage();

        // DRAW
        {
            using constants : *Constants;
            get_constant_buffer_ptr(*constants, *renderer, *constant_buffer);
            Transform   = rotateX * rotateY * rotateZ * scale * translate;
            Projection  = make_matrix4(2 * n / w, 0, 0, 0, 0, 2 * n / h, 0, 0, 0, 0, f / (f - n), 1, 0, 0, n * f / (n - f), 0 );
            LightVector = .{ 1.0, -1.0, 1.0 };
        }

        // viewport
        backgroundColor := Vector4.{ 0.025, 0.025, 0.025, 1.0};

        apply_viewport();

        // setup draw state
        vert_buffers: [1]Buffer;
        vert_buffers[0] = vertex_buffer;
        {
            push_default_pass(*backgroundColor);
            apply_pipeline(*pipeline);
            apply_bindings(*shader, vert_buffers, *index_buffer, *texture);
            apply_constant_buffers(*constant_buffer);
            draw();
        }

        present();
        // END DRAW
    }
}

#scope_file

#load "lib/renderer.jai";

#import "Window_Creation";
#import "Input";
#import "Basic";
#import "Windows";
#import "Math";


#load "data.jai";    // model data
