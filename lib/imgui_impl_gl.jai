//
// an imgui "implementation" based on builtin modules
//

ImGui :: #import "imgui_docking";
ImDrawIdx :: ImGui.ImDrawIdx;
make_ImVec2 :: ImGui.make_ImVec2;

DEBUG_SEVERITY_NOTIFICATION:GLenum: 0x826B;

gl_debug_context: Context;

gl_debug_proc :: (
    source: GLenum,
    type: GLenum,
    id: GLuint,
    severity: GLenum,
    length: GLsizei,
    message: *u8,
    userdata: *void) #c_call
{
    if severity == DEBUG_SEVERITY_NOTIFICATION return;

    ctx := cast(*Context)userdata;
    push_context <<ctx {
        print("GL ERROR: severity: % --- %\n", severity, to_string(message));
    }
}


UI_State :: struct {
    using ui_state_base: UI_State_Base;
    FontTexture: GLuint;
    ShaderHandle: GLuint;
    AttribLocationTex: GLint;
    AttribLocationProjMtx: GLint;
    AttribLocationPosition: GLuint;
    AttribLocationUV: GLuint;
    AttribLocationColor: GLuint;
    VboHandle: GLuint;
    VaoHandle: GLuint;
    ElementsHandle: GLuint;
};

#load "imgui_impl_common.jai";


// This is the main rendering function that you have to implement and provide to ImGui (via setting up 'RenderDrawListsFn' in the ImGuiIO structure)
// Note that this implementation is little overcomplicated because we are saving/setting up/restoring every OpenGL state explicitly, in order to be able to run within any OpenGL engine that doesn't do so. 
// If text or lines are blurry when integrating ImGui in your engine: in your Render function, try translating your projection matrix by (0.5f,0.5f) or (0.375f,0.375f)
ImGui_Impl_RenderDrawData :: (using ui_state: *UI_State, draw_data: *ImGui.ImDrawData) {
    // @@ Watch out, we don't have a context here!

    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    io := ImGui.GetIO();
    fb_width := (io.DisplaySize.x * io.DisplayFramebufferScale.x);
    fb_height := (io.DisplaySize.y * io.DisplayFramebufferScale.y);
    if fb_width == 0 || fb_height == 0 return;
    draw_data.ScaleClipRects(draw_data, io.DisplayFramebufferScale);

    // Backup GL state
    last_active_texture: GLenum;        glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    last_program: GLuint;               glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture: GLuint;               glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    last_sampler: GLuint;               glGetIntegerv(GL_SAMPLER_BINDING, xx *last_sampler);
    last_array_buffer: GLuint;          glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    last_element_array_buffer: GLuint;  glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, xx *last_element_array_buffer);
    last_vertex_array: GLuint;          glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);
    last_polygon_mode: [2]GLuint;       glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);
    last_viewport: [4]GLint;            glGetIntegerv(GL_VIEWPORT, last_viewport.data);
    last_scissor_box : [4]GLint;        glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb: GLenum;         glGetIntegerv(GL_BLEND_SRC_RGB, xx *last_blend_src_rgb);
    last_blend_dst_rgb: GLenum;         glGetIntegerv(GL_BLEND_DST_RGB, xx *last_blend_dst_rgb);
    last_blend_src_alpha: GLenum;       glGetIntegerv(GL_BLEND_SRC_ALPHA, xx *last_blend_src_alpha);
    last_blend_dst_alpha: GLenum;       glGetIntegerv(GL_BLEND_DST_ALPHA, xx *last_blend_dst_alpha);
    last_blend_equation_rgb: GLenum;    glGetIntegerv(GL_BLEND_EQUATION_RGB, xx *last_blend_equation_rgb);
    last_blend_equation_alpha: GLenum;  glGetIntegerv(GL_BLEND_EQUATION_ALPHA, xx *last_blend_equation_alpha);
    last_enable_blend :=                glIsEnabled(GL_BLEND);
    last_enable_cull_face :=            glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test :=           glIsEnabled(GL_DEPTH_TEST);
    last_enable_scissor_test :=         glIsEnabled(GL_SCISSOR_TEST);

    // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled, polygon fill
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_SCISSOR_TEST);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    // Setup viewport, orthographic projection matrix
    glViewport(0, 0, xx fb_width, xx fb_height);

    new_context: Context;
    push_context new_context {
        ortho_projection := orthographic_projection_matrix(0, io.DisplaySize.x, io.DisplaySize.y, 0, 0, 1);
        ortho_projection = transpose(ortho_projection);

        glUseProgram(ShaderHandle);
        glUniform1i(AttribLocationTex, 0);
        glUniformMatrix4fv(AttribLocationProjMtx, 1, GL_FALSE, xx *ortho_projection);
        glBindVertexArray(VaoHandle);
        glBindSampler(0, 0); // Rely on combined texture/sampler state.

        // Render command lists
        for n: 0..draw_data.CmdListsCount-1 {
            cmd_list := draw_data.CmdLists[n];
            idx_buffer_offset : *ImGui.ImDrawIdx;

            glBindBuffer(GL_ARRAY_BUFFER, VboHandle);
            glBufferData(GL_ARRAY_BUFFER, cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert), cmd_list.VtxBuffer.Data, GL_STREAM_DRAW);

            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ElementsHandle);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, cmd_list.IdxBuffer.Size * size_of(ImDrawIdx), cmd_list.IdxBuffer.Data, GL_STREAM_DRAW);

            for cmd_i: 0..cmd_list.CmdBuffer.Size-1 {
                pcmd := *cmd_list.CmdBuffer.Data[cmd_i];
                if pcmd.UserCallback {
                    pcmd.UserCallback(cmd_list, pcmd);
                }
                else {
                    glBindTexture(GL_TEXTURE_2D, xx pcmd.TextureId);
                    glScissor(xx pcmd.ClipRect.x, xx (fb_height - pcmd.ClipRect.w), xx (pcmd.ClipRect.z - pcmd.ClipRect.x), xx (pcmd.ClipRect.w - pcmd.ClipRect.y));
                    
                    glDrawElements(GL_TRIANGLES, pcmd.ElemCount, GL_UNSIGNED_SHORT, idx_buffer_offset);
                }
                idx_buffer_offset += pcmd.ElemCount;
            }
        }

        // Restore modified GL state
        glUseProgram(last_program);
        glBindTexture(GL_TEXTURE_2D, last_texture);
        glBindSampler(0, last_sampler);
        glActiveTexture(last_active_texture);
        glBindVertexArray(last_vertex_array);
        glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, last_element_array_buffer);
        glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
        glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
        if last_enable_blend        glEnable(GL_BLEND);         else glDisable(GL_BLEND);
        if last_enable_cull_face    glEnable(GL_CULL_FACE);     else glDisable(GL_CULL_FACE);
        if last_enable_depth_test   glEnable(GL_DEPTH_TEST);    else glDisable(GL_DEPTH_TEST);
        if last_enable_scissor_test glEnable(GL_SCISSOR_TEST);  else glDisable(GL_SCISSOR_TEST);
        glPolygonMode(GL_FRONT_AND_BACK, last_polygon_mode[0]);
        glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
        glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
    }
}

ImGui_Impl_GetClipboardText :: (data: *void) -> *u8 #c_call {
    new_context: Context; // TODO: hide the context in the userdata pointer passed to us
    push_context new_context {
        return to_c_string(Clipboard.os_clipboard_get_text());
    }
}

ImGui_Impl_SetClipboardText :: (data: *void, text: *u8) #c_call {
    new_context: Context;
    push_context new_context {
        Clipboard.os_clipboard_set_text(to_string(text));
    }
}

#if 0 {
// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
// Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
ImGui_Impl_ProcessEvent :: (using ui_state: *UI_State, event: Input.Event) {
    using Input;
    io := ImGui.GetIO();
    if event.type == {
        // TODO: get mouse move events into jai's input handling code
        //case .MOUSE_MOVE;
            //return true;
        case .MOUSE_WHEEL;
            if event.wheel_delta > 0 MouseWheel = 1;
            if event.wheel_delta < 0 MouseWheel = -1;
        case .KEYBOARD;
            if event.key_code == {
                case .MOUSE_BUTTON_LEFT;   MousePressed[0] = event.key_pressed != 0;
                case .MOUSE_BUTTON_MIDDLE; MousePressed[1] = event.key_pressed != 0;
                case .MOUSE_BUTTON_RIGHT;  MousePressed[2] = event.key_pressed != 0;
                case;
                    io.KeysDown[event.key_code] = event.key_pressed != 0;
                    io.KeyShift = event.shift_pressed;
                    io.KeyCtrl = event.ctrl_pressed;
                    io.KeyAlt = event.alt_pressed;
            }
        case .TEXT_INPUT;
            buf := talloc(size_of(s32) + 1); // unicode rune + 0
            memcpy(buf, *event.utf32, size_of(s32));
            io.AddInputCharactersUTF8(io, buf);
    }
}
}


ImGui_Impl_CreateFontsTexture :: (using ui_state: *UI_State) -> bool {
    io := ImGui.GetIO();
    assert(io != null);
    assert(io.Fonts != null);

    if io.Fonts.TexID != null
        return false;

    // Build texture atlas
    pixels: *u8 = null;
    width, height: s32;
    assert(io.Fonts != null);
    io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);
    assert(pixels != null);
    assert(width > 0);
    assert(height > 0);

    // Upload texture to graphics system
    last_texture: GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);

    glGenTextures(1, *FontTexture);
    glBindTexture(GL_TEXTURE_2D, FontTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    //glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

    // Store our identifier
    io.Fonts.TexID = xx FontTexture;

    // Restore state
    glBindTexture(GL_TEXTURE_2D, last_texture);

    return true;
}

get_shader_program :: (shader_vertex : string, shader_fragment : string) -> GLuint {
    make_shader_object :: (shader : string, shader_type : GLenum) -> GLuint {
        shader_object := glCreateShader(shader_type);

        //shader_str := temp_c_string(shader);
		length : GLint = xx shader.count;
        glShaderSource(shader_object, 1, *shader.data, *length);

        glCompileShader(shader_object);

        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success then {
            log : [512] u8;
            glGetShaderInfoLog(shader_object, 512, null, log.data);
            print("[Shader] %\n", to_string(log.data));
        }

        return shader_object;
    }

    shader_v := make_shader_object(shader_vertex, GL_VERTEX_SHADER);
    shader_f := make_shader_object(shader_fragment, GL_FRAGMENT_SHADER);
    shader_p := glCreateProgram();

    glAttachShader(shader_p, shader_v);
    glAttachShader(shader_p, shader_f);
    glLinkProgram(shader_p);

    success : GLint = 0;
    glGetProgramiv(shader_p, GL_LINK_STATUS, *success);

    if !success then {
        BUFFER_SIZE_LOG :: 512;
        log : [BUFFER_SIZE_LOG] u8;
        glGetProgramInfoLog(shader_p, BUFFER_SIZE_LOG, null, log.data);
        print("[Shader] %\n", to_string(log.data));
    } 

    glDeleteShader(shader_v);
    glDeleteShader(shader_f);

    return shader_p;
}

ImGui_Impl_CreateDeviceObjects :: (using ui_state: *UI_State) -> bool {
    // Backup GL state
    last_texture, last_array_buffer, last_vertex_array: GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);

    vertex_shader := #string END
        #version 330
        uniform mat4 ProjMtx;
        in vec2 Position;
        in vec2 UV;
        in vec4 Color;
        out vec2 Frag_UV;
        out vec4 Frag_Color;
        void main() {
           Frag_UV = UV;
           Frag_Color = Color;
           gl_Position = ProjMtx * vec4(Position.xy,0,1);
        }
    END

    fragment_shader := #string END
        #version 330
        uniform sampler2D Texture;
        in vec2 Frag_UV;
        in vec4 Frag_Color;
        out vec4 Out_Color;
        void main() {
           Out_Color = Frag_Color * texture(Texture, Frag_UV.st);
        }
    END

    ShaderHandle = get_shader_program(vertex_shader, fragment_shader);

    AttribLocationTex = glGetUniformLocation(ShaderHandle, "Texture");
    AttribLocationProjMtx = glGetUniformLocation(ShaderHandle, "ProjMtx");
    AttribLocationPosition = xx glGetAttribLocation(ShaderHandle, "Position");
    AttribLocationUV = xx glGetAttribLocation(ShaderHandle, "UV");
    AttribLocationColor = xx glGetAttribLocation(ShaderHandle, "Color");

    glGenBuffers(1, *VboHandle);
    glGenBuffers(1, *ElementsHandle);

    glGenVertexArrays(1, *VaoHandle);
    glBindVertexArray(VaoHandle);
    glBindBuffer(GL_ARRAY_BUFFER, VboHandle);
    glEnableVertexAttribArray(AttribLocationPosition);
    glEnableVertexAttribArray(xx AttribLocationUV);
    glEnableVertexAttribArray(xx AttribLocationColor);

    // @@ Is there a function to easily get the offset of a member?
    //ImGui.ImDrawVert :: struct {
    //   pos: ImVec2;       // 0
    //   uv: ImVec2;        // 8
    //   col: s32;          // 16
    //}
    glVertexAttribPointer(AttribLocationPosition, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 0);
    glVertexAttribPointer(AttribLocationUV, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 8);
    glVertexAttribPointer(AttribLocationColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, size_of(ImGui.ImDrawVert), xx 16);

    ImGui_Impl_CreateFontsTexture(ui_state);

    // Restore modified GL state
    glBindTexture(GL_TEXTURE_2D, last_texture);
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
    glBindVertexArray(last_vertex_array);

    return true;
}


ImGui_Impl_InvalidateDeviceObjects :: (using ui_state: *UI_State) {
    if FontTexture {
        glDeleteTextures(1, *FontTexture);
        ImGui.GetIO().Fonts.TexID = null;
        FontTexture = 0;
    }
}

#if OS == .WINDOWS {

Win32 :: #import "Windows";
get_client_mouse_pos :: (window: *void) -> (x: s32, y: s32) {
    point: Win32.POINT;
    Win32.GetCursorPos(*point);
    Win32.ScreenToClient(window, *point);
    return point.x, point.y;
}

}


ImGui_Impl_Init :: (using ui_state: *UI_State, native_window_handle: *void) -> bool {
    assert(ctx != null, "must call create context");
    ImGui.SetCurrentContext(ctx);
    //print("imgui version %\n", to_string(ImGui.GetVersion()));

    io := ImGui.GetIO();
    {
        // raylib keys
        using rl.KeyboardKey;

        io.KeyMap[ImGui.Key.Tab]        = xx KEY_TAB;
        io.KeyMap[ImGui.Key.LeftArrow]  = xx KEY_LEFT;
        io.KeyMap[ImGui.Key.RightArrow] = xx KEY_RIGHT;
        io.KeyMap[ImGui.Key.UpArrow]    = xx KEY_UP;
        io.KeyMap[ImGui.Key.DownArrow]  = xx KEY_DOWN;
        io.KeyMap[ImGui.Key.Backspace]  = xx KEY_BACKSPACE;
        io.KeyMap[ImGui.Key.PageUp]     = xx KEY_PAGE_UP;
        io.KeyMap[ImGui.Key.PageDown]   = xx KEY_PAGE_DOWN;
        io.KeyMap[ImGui.Key.Home]       = xx KEY_HOME;
        io.KeyMap[ImGui.Key.End]        = xx KEY_END;
        io.KeyMap[ImGui.Key.Delete]     = xx KEY_DELETE;
        io.KeyMap[ImGui.Key.Backspace]  = xx KEY_BACKSPACE;
        io.KeyMap[ImGui.Key.Enter]      = xx KEY_ENTER;
        io.KeyMap[ImGui.Key.Escape]     = xx KEY_ESCAPE;
        io.KeyMap[ImGui.Key.A]          = xx KEY_A;
        io.KeyMap[ImGui.Key.C]          = xx KEY_C;
        io.KeyMap[ImGui.Key.V]          = xx KEY_V;
        io.KeyMap[ImGui.Key.X]          = xx KEY_X;
        io.KeyMap[ImGui.Key.Y]          = xx KEY_Y;
        io.KeyMap[ImGui.Key.Z]          = xx KEY_Z;
    }

    #if 0 {
        using Input.Key_Code;
        // these are from the Jai input library
        io.KeyMap[ImGui.Key.Tab] = xx TAB;                     // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
        io.KeyMap[ImGui.Key.LeftArrow] = xx ARROW_LEFT;
        io.KeyMap[ImGui.Key.RightArrow] = xx ARROW_RIGHT;
        io.KeyMap[ImGui.Key.UpArrow] = xx ARROW_UP;
        io.KeyMap[ImGui.Key.DownArrow] = xx ARROW_DOWN;
        io.KeyMap[ImGui.Key.PageUp] = xx PAGE_UP;
        io.KeyMap[ImGui.Key.PageDown] = xx PAGE_DOWN;
        io.KeyMap[ImGui.Key.Home] = xx HOME;
        io.KeyMap[ImGui.Key.End] = xx END;
        io.KeyMap[ImGui.Key.Delete] = xx DELETE;
        io.KeyMap[ImGui.Key.Backspace] = xx BACKSPACE;
        io.KeyMap[ImGui.Key.Enter] = xx ENTER;
        io.KeyMap[ImGui.Key.Escape] = xx ESCAPE;
        io.KeyMap[ImGui.Key.A] = xx #char "A";
        io.KeyMap[ImGui.Key.C] = xx #char "C";
        io.KeyMap[ImGui.Key.V] = xx #char "V";
        io.KeyMap[ImGui.Key.X] = xx #char "X";
        io.KeyMap[ImGui.Key.Y] = xx #char "Y";
        io.KeyMap[ImGui.Key.Z] = xx #char "Z";
    }

    // io.RenderDrawListsFn = ImGui_Impl_RenderDrawLists;   // Alternatively you can set this to NULL and call ImGui::GetDrawData() after ImGui::Render() to get the same ImGui.ImDrawData pointer.
    io.SetClipboardTextFn = ImGui_Impl_SetClipboardText;
    io.GetClipboardTextFn = ImGui_Impl_GetClipboardText;
    io.ClipboardUserData = null;

    #if OS == .WINDOWS {
        // TODO: did imgui remove ImeWindowHandle?
        //io.ImeWindowHandle = native_window_handle;
    }

    // TODO: Cursors

    ImGui_Impl_CreateDeviceObjects(ui_state);

    return true;
}

ImGui_ImplSdl_Shutdown :: (ui_state: *UI_State) {
    ImGui.SetCurrentContext(ui_state.ctx);
    ImGui_Impl_InvalidateDeviceObjects(ui_state);
    ImGui.DestroyContext();
    ui_state.ctx = null;
}


ImGui_Impl_SetupGLContext :: () {
    gl_load(*gl);
    glEnable(GL_DEBUG_OUTPUT);
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
    gl_debug_context = context;
    glDebugMessageCallback(gl_debug_proc, *gl_debug_context);
}

ImGui_Impl_NewFrame :: (ui_state: *UI_State, native_window_handle: *void, display_width: s32, display_height: s32) {
    using ui_state;

    io := ImGui.GetIO();

    // Setup display size (every frame to accommodate for window resizing)
    io.DisplaySize = make_ImVec2(xx display_width, xx display_height);
    io.DisplayFramebufferScale = make_ImVec2(1, 1);

    // Setup time step
    current_time := get_time();
    if Time > 0.0 io.DeltaTime = xx (current_time - Time);
    else io.DeltaTime = (1.0/60.0);
    Time = current_time;

    // Setup inputs
    mx, my := get_client_mouse_pos(native_window_handle);
    io.MousePos = make_ImVec2(xx mx, xx my);

    io.MouseDown[0] = MousePressed[0];      // If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
    io.MouseDown[1] = MousePressed[1];
    io.MouseDown[2] = MousePressed[2];

    io.MouseWheel = MouseWheel;
    MouseWheel = 0.0;

    // Hide OS mouse cursor if ImGui is drawing it
    // TODO: cursors

    // Start the frame. This call will update the io.WantCaptureMouse, io.WantCaptureKeyboard flag that you can use to dispatch inputs (or not) to your application.
    ImGui.NewFrame();
}

#scope_file

#import "Basic";
#import "Window_Creation";
#import "Math";
#import "Compiler";
#import "GL";
#run compiler_set_type_info_flags(GL_Procedures, .NO_SIZE_COMPLAINT);
Clipboard :: #import "Clipboard";
Input :: #import "Input";
rl :: #import "raylib";


