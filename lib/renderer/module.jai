// Common implementation

/*

ok so here's a problem to fix!

    i made a mistake when making ANOTHER renderer for the second window.
    really i should have made a swap chain object (or something), and then
    created another one of those, and then used push_swapchain(*lkg_swapchain).

    an example of the problem: Renderer_Base here has reloadable_shaders, storing
    a list of filenames linked to shader pointers. but...the shaders are for the same device!
    it doesn't make sense to have two "virtual devices." part of the problem is naming it "Renderer."

    but really the second window should not have a second renderer pointer.

    */

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

reload_shaders_with_filename :: (filename: string) -> (did_reload: bool) {
    using renderer := assert_state();
    did_reload := false;
    for reloadable_shaders {
        if it.filename == filename {
            for shader: it.shaders {
                reload_shader(shader);
                did_reload = true;
            }
        }
    }
    return did_reload;
}

add_reloadable_shader :: (filename: string, shader: *Shader) -> *Shader_Reload_Entry, bool {
    using renderer := assert_state();
    assert(filename.count > 0);

    entry: *Shader_Reload_Entry;
    for * reloadable_shaders {
        if it.filename == filename {
            entry = it;
            break;
        }
    }
    if !entry {
        entry = array_add(*reloadable_shaders);
        entry.filename = copy_string(filename);
    }

    did_add := array_add_if_unique(*entry.shaders, shader);
    return entry, did_add;
}

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

Buffer_Usage_Flags :: enum_flags u8 {
    Default :: 0;
    Staging :: 1;
}

Primitive_Type :: enum u8 {
    Triangles;
    Line_List;
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

get_renderer_ptr :: () -> *Renderer { return renderer; }

set_context :: (renderer_ptr: *Renderer) {
    renderer = renderer_ptr;
}

push_renderer_context :: (renderer_ptr: *Renderer, debug_string := "") #expand {
    assert(renderer_ptr != null);
    old_val := renderer;
    renderer = renderer_ptr;
    //print("pushing renderer % %\n", renderer, debug_string);
    `defer {
        renderer = old_val;
        //print("popped renderer back to % from %\n", renderer, debug_string);
    }
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

resize_if_necesssary :: (texture: *Texture, size: Vector2_u16) -> bool {
    if size.x > 0 && size.y > 0 {
        if size.x != texture.width || size.y != texture.height {
            resize_texture(texture, size);
            return true;
        }
    }

    return false;
}

// TODO: replace Buffer with this? it's probably better to be type-safe always!
// and if we want differently typed views of the same underying GPU memory, we
// can use an "owned" flag
GPU_Buffer :: struct(T: Type) {
    Elem_Type :: T;

    buffer: Buffer;
}

is_initialized :: (gpu_buffer: GPU_Buffer) -> bool { return is_initialized(gpu_buffer.buffer); }

create_gpu_buffer :: ($T: Type, count: u32, debug_name := "") -> GPU_Buffer(T) {
    total_size_in_bytes:u32 = size_of(T) * count; // TODO: ALIGNMENT???

    gpu_buffer: GPU_Buffer(T);
    gpu_buffer.buffer = create_constant_buffer(total_size_in_bytes);
    return gpu_buffer;
}

/*
    #if #run type_info(T).type == .ARRAY {
        ti := type_info(T);
        ti_array := cast(*Type_Info_Array)ti;
        if ti.array_type == .FIXED {
            ti_array := cast(*Type_Info_Array)type_info(T);
            print("ti_array: %\n", ti_array);
            print("  count: %\n", ti_array.array_count);
            print("  array_tpe: %\n", ti_array.element_type);

            //todo. encode some metadata about the type in Buffer? or rethink buffers to be able to have a typesafe wrapper? I think maybe that's the better option here.
        }
    }
    // TODO: maybe Buffer should be surrounded by a thing which is parameterized by T?
*/

#load "renderer_d3d11.jai";

