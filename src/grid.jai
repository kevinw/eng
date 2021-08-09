init :: (using state: *State) {
    ok := load_shader_from_file(*shader, "resources/shaders/line_grid.hlsl",
        vs_main="LineGridVS", ps_main="LineGridPS", debug_name_postfix="EditorGrid");
    assert(ok, "Could not load grid shader.");

    pipeline = make_pipeline(
        shader=*shader,
        primitive_type=.Line_List,
        cull_mode=.None,
        blend_mode=.Default,
        label="Editor Grid Lines",
    );

    constant_buffer = create_constant_buffer(Grid_Constants, debug_name="grid constants");
}

draw :: (using state: *State, cam_matrix: Matrix4) {
    constants: *Grid_Constants;
    ROWS :: 50;
    {
        get_constant_buffer_ptr(*constants, *constant_buffer);
        constants.WorldViewProjection = cam_matrix;
        constants.Rows = ROWS;
    }

    apply_viewport();
    apply_pipeline(*pipeline);
    apply_bindings(*shader, vertex_buffers=.[], index_buffer=null);
    apply_constant_buffers(.Vertex, *constant_buffer);
    draw((ROWS + 1) * 4);
}

State :: struct {
    pipeline: Pipeline;
    shader: Shader;
    constant_buffer: Buffer;
}

#scope_file

#import "renderer";
#import "Math";
#import "Basic";

Grid_Constants :: struct {
    WorldViewProjection: Matrix4;
    Rows: u32;
}

