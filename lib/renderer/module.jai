// Common implementation

SUPPORT_RELOADABLE_SHADERS :: true;

Renderer_Base :: struct {
    current_pass: *Pass;
    in_pass: bool;

    debug_message_callback: Debug_Message_Callback;

    reloadable_shaders: [..]Shader_Reload_Entry;
}

Shader_Reload_Entry :: struct {
    filename: string;
    shaders: [..]*Shader;
}

Debug_Message_Callback :: #type (msg: Debug_Message);

Debug_Message :: struct {
    text: string;
    severity: Severity;

    Severity :: enum u32 {
        Corruption :: D3D11_MESSAGE_SEVERITY.CORRUPTION;
        Error      :: D3D11_MESSAGE_SEVERITY.ERROR;
        Warning    :: D3D11_MESSAGE_SEVERITY.WARNING;
        Info       :: D3D11_MESSAGE_SEVERITY.INFO;
        Message    :: D3D11_MESSAGE_SEVERITY.MESSAGE;
    }
}

#if SUPPORT_RELOADABLE_SHADERS {
    reload_shaders_with_filename :: (filename: string) -> (did_reload: bool) {
        using renderer := assert_state();
        for reloadable_shaders if it.filename == filename
            for shader: it.shaders
                reload_shader(shader);
        return false;
    }

    add_reloadable_shader :: (filename: string, shader: *Shader) -> bool {
        assert(filename.count > 0);

        using renderer := assert_state();
        entry := array_add_if_unique_by_lambda(*reloadable_shaders, filename, e => *e.filename);
        return array_add_if_unique(*entry.shaders, shader);
    }
} // SUPPORT_RELOADABLE_SHADERS

Create_Texture_Type :: enum {
    Normal;
    Render_Target_Color;
    Render_Target_Depth;
}


Buffer_Type :: enum u8 {
    Vertex;
    Index;
    Constant;
}

Primitive_Type :: enum u8 {
    Triangles;
}

Cull_Mode :: enum u8 {
    None  :: 0;
    Front :: 1;
    Back  :: 2;
}

Blend_Mode :: enum {
    Default;
    Alpha_Blended;
}

Depth_Stencil_Opts :: struct {
    depth_write := true;
    depth_compare_func: Depth_Compare_Func = .Less;
}

renderer: *Renderer; // a pointer, so that the user of this module can tell us where the memory is

set_global_renderer_ptr :: (new_renderer: *Renderer) {
    renderer = new_renderer;
}

set_context :: (renderer_ptr: *Renderer) {
    renderer = renderer_ptr;
}

assert_state :: inline () -> *Renderer {
    assert(renderer != null, "must call init(*renderer) first");
    return renderer;
}

set_debug_callback :: (cb: Debug_Message_Callback) {
    renderer := assert_state();
    renderer.debug_message_callback = cb;
}

begin_default_pass :: (clear_color: *Vector4 = null) {
    begin_pass(null, clear_color);
}


push_pass :: (pass: *Pass, clear_color: *Vector4 = null) #expand {
    begin_pass(pass, clear_color);
    `defer end_pass();
}

push_default_pass :: (clear_color: *Vector4 = null, enabled := true) #expand {
    begin_default_pass(clear_color);
    `defer end_pass();
}

#load "renderer_d3d11.jai";

#scope_file

array_add_if_unique_by_lambda :: inline (array: *[..] $T, item: $V, predicate: #type (t: *T) -> *V) -> *T {
    for * <<array
        if <<predicate(it) == item
            return it;

    new_entry := array_add(array);
    new_entry_value := predicate(new_entry);
    <<new_entry_value = item;
    return new_entry;
}


