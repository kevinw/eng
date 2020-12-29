// Common implementation

Renderer_Base :: struct {
    current_pass: *Pass;
    in_pass: bool;

    debug_message_callback: Debug_Message_Callback;
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

// D3D11 implementation

Renderer :: struct {
    using base: Renderer_Base;
    current_index_buffer: *Buffer;

    // d3d11
    device: *ID3D11Device1;
    device_context1: *ID3D11DeviceContext1;
    swap_chain: *IDXGISwapChain1;

    // swapchain backbuffer
    frame_buffer: *ID3D11Texture2D;
    frame_buffer_view: *ID3D11RenderTargetView;

    depth_buffer: *ID3D11Texture2D;
    depth_buffer_view: *ID3D11DepthStencilView;
    depth_buffer_desc: D3D11_TEXTURE2D_DESC;

    debug_info_queue: *ID3D11InfoQueue;

    white_texture: Texture;
}

Shader :: struct {
    // d3d11
    vert: *ID3D11VertexShader;
    frag: *ID3D11PixelShader;

    vs_blob: *ID3DBlob;
    ps_blob: *ID3DBlob;

    input_layout: *ID3D11InputLayout;
    input_layout_byte_length: u32;
}


Texture :: struct {
    width: u16;
    height: u16;

    #place width;
    size: Vector2_u16;

    texture2D:     *ID3D11Texture2D;
    views:         [..]*ID3D11ShaderResourceView; // 0 is the main one; 1-N are single views of an array texture
    sampler_state: *ID3D11SamplerState;

    debug_name: string; @debug @owned
}

Pass :: struct { // TODO: rename to render target
    color: [4]*Texture; // TODO...not sure this makes the most sense.
    depth: *Texture;
    label: string;

    frame_buffer_view: *ID3D11RenderTargetView;
    depth_buffer_view: *ID3D11DepthStencilView;
}

Pipeline :: struct {
    shader: *Shader; // TODO: some kind of pool is gonna be necessary here...

    // d3d11
    rasterizer_state: *ID3D11RasterizerState1;
    primitive_type: D3D11_PRIMITIVE_TOPOLOGY;
    depth_stencil_state: *ID3D11DepthStencilState;
    blend_state:         *ID3D11BlendState;
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


Buffer :: struct {
    d3d_buffer: *ID3D11Buffer;

    element_count: u32; // not sure this should be here...
}


////////

set_debug_callback :: (cb: Debug_Message_Callback) {
    renderer := assert_state();
    renderer.debug_message_callback = cb;
}

framebuffer_size :: () -> Vector2_u16 {
    using renderer := assert_state();
    return v2u16(xx depth_buffer_desc.Width, xx depth_buffer_desc.Height);
}

resize_swapchain :: (w: u32, h: u32) {
    using renderer := assert_state();
    assert(w > 0);
    assert(h > 0);

    if w == depth_buffer_desc.Width && h == depth_buffer_desc.Height
        return; // no actual size change

    Release(frame_buffer);
    Release(frame_buffer_view);
    Release(depth_buffer);
    Release(depth_buffer_view);
    check_result(swap_chain.ResizeBuffers(
        xx swap_chain,
        BufferCount = 0,
        Width = w,
        Height = h,
        NewFormat = .DXGI_FORMAT_UNKNOWN, // UNKNOWN here means "keep the format the same"
        SwapChainFlags = 0,
    ));

    _get_swapchain_framebuffer(renderer);

    // Width and Height in the depth_buffer_desc are what we use to tell the
    // rest of the system how big our framebuffer is, for now.
    assert(renderer.depth_buffer_desc.Width == w);
    assert(renderer.depth_buffer_desc.Height == h);
}

draw :: (num_elements: int = -1, num_instances: u32 = 1, base_element: u32 = 0) {
    using renderer := assert_state();

    assert(in_pass, "must call begin_pass before draw");

    if current_index_buffer != null {
        num_elements_to_draw: u32;
        if num_elements == -1 {
            num_elements_to_draw = current_index_buffer.element_count;
            assert(num_elements_to_draw > 0);
        }
        else
            num_elements_to_draw = cast(u32)num_elements;

        if 1 == num_instances {
            device_context1.DrawIndexed(xx device_context1, num_elements_to_draw, base_element, 0);
        } else {
            device_context1.DrawIndexedInstanced(xx device_context1, num_elements_to_draw, num_instances, base_element, 0, 0);
        }
    } else {
        assert(num_elements != -1, "TODO: is it possible just to know how many elements to draw when there's no index buffer?");
        num_elements_to_draw := cast(u32)num_elements;
        if 1 == num_instances
            device_context1.Draw(xx device_context1, num_elements_to_draw, base_element);
        else
            device_context1.DrawInstanced(xx device_context1, num_elements_to_draw, num_instances, base_element, 0);
    }
}

apply_bindings :: (shader: *Shader,
    vertex_buffers: []Buffer,
    index_buffer: *Buffer,
    textures: ..*Texture
) {

    device_context := cast(*ID3D11DeviceContext)renderer.device_context1;

    renderer.current_index_buffer = index_buffer;

    vert_buffers: [..]*ID3D11Buffer;
    vert_buffers.allocator = __temporary_allocator;
    for vertex_buffers array_add(*vert_buffers, it.d3d_buffer);

    vert_strides: [..]u32;
    vert_strides.allocator = __temporary_allocator;
    for vertex_buffers array_add(*vert_strides, shader.input_layout_byte_length); // TODO: this isn't right. input layout only has one slot?

    vert_offsets: [..]u32;
    vert_offsets.allocator = __temporary_allocator;
    for vertex_buffers array_add(*vert_offsets, 0);

    device_context.IASetVertexBuffers(device_context, 0, cast(u32)vert_buffers.count, vert_buffers.data, vert_strides.data, vert_offsets.data);

    if index_buffer != null {
        device_context.IASetIndexBuffer(device_context, index_buffer.d3d_buffer, .DXGI_FORMAT_R32_UINT, 0);
    } else {
        device_context.IASetIndexBuffer(device_context, null, .DXGI_FORMAT_UNKNOWN, 0);
    }

    shader_resource_views: [..]*ID3D11ShaderResourceView;
    shader_resource_views.allocator = __temporary_allocator;

    sampler_states: [..]*ID3D11SamplerState;
    sampler_states.allocator = __temporary_allocator;

    for textures {
        local_texture := it;
        if it == null {
            logprint("renderer", "warning: passed a null texture to apply_bindings");
            continue;
        }
        if it.views.count > 1 {
            array_add(*shader_resource_views, it.views[1]);
        } else {
            if it.views.count == 0
                print("texture '%' has no views!\n", it.debug_name);
            assert(it.views[0] != null, tprint("texture '%' had a null view", it.debug_name));
            array_add(*shader_resource_views, it.views[0]);
        }

        assert(it.sampler_state != null, "texture had a null sampler state");
        array_add(*sampler_states, it.sampler_state);
    }

    device_context.PSSetShaderResources(device_context, 0, cast(u32)shader_resource_views.count, shader_resource_views.data);
    flush_debug_messages();

    device_context.PSSetSamplers(device_context, 0, cast(u32)sampler_states.count, sampler_states.data);
    flush_debug_messages();

    //ID3D11DeviceContext_IASetVertexBuffers(_sg.d3d11.ctx, 0, SG_MAX_SHADERSTAGE_BUFFERS, d3d11_vbs, pip->d3d11_vb_strides, d3d11_vb_offsets);
    //ID3D11DeviceContext_IASetIndexBuffer(_sg.d3d11.ctx, d3d11_ib, pip->d3d11_index_format, ib_offset);
}

create_constant_buffer :: ($T: Type) -> Buffer {
    // TODO: maybe Buffer should be surrounded by a thing which is parameterized by T?
    assert_state();
    using renderer;

    constant_buffer_desc := D3D11_BUFFER_DESC.{
        ByteWidth      = #run next_multiple_of(16, size_of(T)),
        Usage          = .D3D11_USAGE_DYNAMIC,
        BindFlags      = .D3D11_BIND_CONSTANT_BUFFER,
        CPUAccessFlags = .D3D11_CPU_ACCESS_WRITE,
    };

    buf: Buffer;
    check_result(device.CreateBuffer(xx device, *constant_buffer_desc, null, *buf.d3d_buffer));
    return buf;
}

create_dynamic_buffer :: (size_in_bytes: u32, type: Buffer_Type) -> Buffer {
    assert_state();
    using renderer;

    desc: D3D11_BUFFER_DESC;
    desc.ByteWidth      = size_in_bytes;
    desc.Usage          = .D3D11_USAGE_DYNAMIC;
    desc.CPUAccessFlags = .D3D11_CPU_ACCESS_WRITE;
    desc.BindFlags      = get_d3d_bind_flags(type);

    buffer: Buffer;
    check_result(device.CreateBuffer(xx device, *desc, null, *buffer.d3d_buffer));
    buffer.element_count = 0;
    return buffer;
}

get_d3d_bind_flags :: (type: Buffer_Type) -> D3D11_BIND_FLAG {
    if type == {
        case .Vertex; return .D3D11_BIND_VERTEX_BUFFER;
        case .Index;  return .D3D11_BIND_INDEX_BUFFER;
        case; assert(false);
    }
    return 0;
}

Create_Texture_Type :: enum {
    Normal;
    Render_Target_Color;
    Render_Target_Depth;
}

create_texture :: (tex: *Texture, size: Vector2_u16, array_size:u32 = 1, 
    type := Create_Texture_Type.Normal, format: Texture_Format = .BGRA8, label := "") -> bool
{
    using renderer := assert_state();

    bind_flags: D3D11_BIND_FLAG;
    if type == {
        case .Render_Target_Color;
            bind_flags |= .D3D11_BIND_RENDER_TARGET;
            bind_flags |= .D3D11_BIND_SHADER_RESOURCE;
        case .Render_Target_Depth; bind_flags |= .D3D11_BIND_DEPTH_STENCIL;
        case .Normal;              bind_flags |= .D3D11_BIND_SHADER_RESOURCE;
    }

    desc := D3D11_TEXTURE2D_DESC.{
        MipLevels          = 1,
        SampleDesc.Count   = 1,
        Usage              = .D3D11_USAGE_DEFAULT,
    };
    desc.Width     = size.width;
    desc.Height    = size.height;
    desc.ArraySize = array_size;

    if format == {
        case .BGRA8;
            desc.Format = .DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
        case .D24S8;
            bind_flags  |= .D3D11_BIND_DEPTH_STENCIL;
            desc.Format =  .DXGI_FORMAT_D24_UNORM_S8_UINT;
        case;
            assert(false);
    }

    desc.BindFlags = bind_flags;

    texture_data : *D3D11_SUBRESOURCE_DATA = null;

    assert(tex.texture2D == null, "TODO: figure out reinit semantics...");
    tex.size = size;
    tex.debug_name = copy_string(label);
    if S_OK != device.CreateTexture2D(xx device, *desc, texture_data, *tex.texture2D) {
        flush_errors();
        return false;
    }

    //print("CREATE TEXTURE % %x%\n", label, size.width, size.height);

    if bind_flags & .D3D11_BIND_SHADER_RESOURCE != 0 {
        //print("creating shader resource view for texture: %\n", label);

        {
            view: *ID3D11ShaderResourceView;
            if S_OK != renderer.device.CreateShaderResourceView(xx renderer.device, xx tex.texture2D, null, *view) {
                flush_errors();
                return false;
            }
            array_add(*tex.views, view);
        }

        if array_size > 1 {
            // TODO: here's a hack where I'm making a ShaderResourceView object
            // for each single texture layer in a TextureArray. this is so that
            // later, if we want to render just one texture out of the stack,
            // we have an SRV ready. perhaps instead these should be made
            // lazily though? It might be annoying that I have to keep the format
            // around, but still...
            for slice_index: 0..array_size - 1 {
                single_desc := D3D11_SHADER_RESOURCE_VIEW_DESC.{
                    ViewDimension = .D3D11_SRV_DIMENSION_TEXTURE2DARRAY,
                    Texture2DArray = .{
                        MostDetailedMip = 0,
                        MipLevels = cast,trunc(u32)-1,
                        ArraySize = 1,
                    }
                };
                single_desc.Format = desc.Format;
                single_desc.Texture2DArray.FirstArraySlice = slice_index;

                view: *ID3D11ShaderResourceView;
                if S_OK != renderer.device.CreateShaderResourceView(xx renderer.device, xx tex.texture2D, *single_desc, *view) {
                    flush_errors();
                    return false;
                }
                array_add(*tex.views, view);
            }
        }

        assert(!tex.sampler_state);

        // Sampler
        sampler_desc := D3D11_SAMPLER_DESC.{
            //Filter         = .D3D11_FILTER_MIN_MAG_MIP_POINT,
            Filter         = .D3D11_FILTER_MIN_MAG_MIP_LINEAR,
            AddressU       = .D3D11_TEXTURE_ADDRESS_WRAP,
            AddressV       = .D3D11_TEXTURE_ADDRESS_WRAP,
            AddressW       = .D3D11_TEXTURE_ADDRESS_WRAP,
            ComparisonFunc = .D3D11_COMPARISON_NEVER,
        };
        {
            res := renderer.device.CreateSamplerState(xx renderer.device, *sampler_desc, *tex.sampler_state);
            if res != S_OK || tex.sampler_state == null {
                flush_errors();
                return false;
            }
        }
    }

    return true;
}

create_immutable_buffer :: (data: []$D, type: Buffer_Type) -> Buffer {
    assert_state();
    using renderer;

    desc: D3D11_BUFFER_DESC;
    desc.ByteWidth = cast(u32)(size_of(D) * data.count);
    desc.Usage     = .D3D11_USAGE_IMMUTABLE;
    desc.BindFlags = get_d3d_bind_flags(type);

    subresource_data: D3D11_SUBRESOURCE_DATA;
    subresource_data.pSysMem = data.data;

    buffer: Buffer;
    check_result(device.CreateBuffer(xx device, *desc, *subresource_data, *buffer.d3d_buffer));
    buffer.element_count = cast(u32)data.count;
    return buffer;
}

begin_pass :: (pass: *Pass, clear_color: *Vector4 = null) {
    assert_state();

    assert(!renderer.in_pass, "begin_pass called again with first calling end_pass for the previous one");
    renderer.in_pass = true;
    renderer.current_pass = pass;

    framebuffers: []*ID3D11RenderTargetView;
    depth: *ID3D11DepthStencilView;

    if pass == null {
        // the default pass--we render to the screen's render target and depth buffer
        framebuffers.data = *renderer.frame_buffer_view;
        framebuffers.count = 1;
        depth = renderer.depth_buffer_view;
    } else {
        // TODO: do some kind of "init_pass" thing so we don't have to check these every time
        if pass.frame_buffer_view == null {
            assert(pass.color[0] != null);
            check_result(renderer.device.CreateRenderTargetView(
                cast(*ID3D11Device)renderer.device, cast(*ID3D11Resource)pass.color[0].texture2D, null, *pass.frame_buffer_view));
        }
        if pass.depth_buffer_view == null {
            assert(pass.depth != null);
            check_result(renderer.device.CreateDepthStencilView(
                cast(*ID3D11Device)renderer.device, cast(*ID3D11Resource)pass.depth.texture2D, null, *pass.depth_buffer_view));
        }
        framebuffers.data = *pass.frame_buffer_view;
        framebuffers.count = 1;

        depth = pass.depth_buffer_view;
    }

    device_context := cast(*ID3D11DeviceContext)renderer.device_context1;

    if clear_color != null
        for framebuffers
            device_context.ClearRenderTargetView(device_context, it, cast(*[4]float)clear_color);

    // TODO: pass actions, depth clear options
    if depth != null
        device_context.ClearDepthStencilView(device_context, depth, cast(u32)D3D11_CLEAR_DEPTH, 1.0, 0);

    device_context.OMSetRenderTargets(device_context, cast(u32)framebuffers.count, framebuffers.data, depth);
}

begin_default_pass :: (clear_color: *Vector4 = null) {
    begin_pass(null, clear_color);
}

end_pass :: () {
    renderer := assert_state();

    assert(renderer.in_pass, "called end_pass without a corresponding begin_pass");
    renderer.in_pass = false;
    renderer.current_pass = null;
    renderer.device_context1.ClearState(xx renderer.device_context1);
}

push_pass :: (pass: *Pass, clear_color: *Vector4 = null) #expand {
    begin_pass(pass, clear_color);
    `defer end_pass();
}

push_default_pass :: (clear_color: *Vector4 = null, enabled := true) #expand {
    begin_default_pass(clear_color);
    `defer end_pass();
}

check_result :: (hresult: HRESULT, loc := #caller_location) {
    if hresult != S_OK {
        flush_errors();
        assert(hresult == S_OK, tprint("HRESULT was %", formatInt(hresult, base=16)), loc=loc);
    }
}

unload_shader :: (using shader: *Shader) {
    print("TODO: unload_shader\n");
}

Blend_Mode :: enum {
    Default;
    Alpha_Blended;
}

Depth_Compare_Func :: enum {
    Less   :: D3D11_COMPARISON_LESS;
    Always :: D3D11_COMPARISON_ALWAYS;
}

Depth_Stencil_Opts :: struct {
    depth_write := true;
    depth_compare_func: Depth_Compare_Func = .Less;
}


make_pipeline :: (
    shader:             *Shader,
    primitive_type:     Primitive_Type     = .Triangles,
    cull_mode:          Cull_Mode          = .Back,
    blend_mode:         Blend_Mode         = .Default,
    depth_stencil_opts: Depth_Stencil_Opts = .{}
) -> Pipeline {
    assert_state();

    pipeline: Pipeline;
    pipeline.shader = shader;

    device := cast(*ID3D11Device)renderer.device;

    d3d_cull_mode: D3D11_CULL_MODE;
    if cull_mode == {
        case .None;  d3d_cull_mode = .D3D11_CULL_NONE;
        case .Back;  d3d_cull_mode = .D3D11_CULL_BACK;
        case .Front; d3d_cull_mode = .D3D11_CULL_FRONT;
        case; assert(false);
    }

    // d3d11
    rasterizer_desc := D3D11_RASTERIZER_DESC1.{
        FillMode = .D3D11_FILL_SOLID,
    };
    rasterizer_desc.CullMode = d3d_cull_mode;

    check_result(renderer.device.CreateRasterizerState1(
        renderer.device, *rasterizer_desc, *pipeline.rasterizer_state));

    if primitive_type == {
        case .Triangles; pipeline.primitive_type = .D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST;
        case; assert(false, "TODO: impl");
    }

    // depth stencil state
    depth_stencil_desc := D3D11_DEPTH_STENCIL_DESC.{
        DepthWriteMask = .D3D11_DEPTH_WRITE_MASK_ALL,
    };
    depth_stencil_desc.DepthEnable = ifx depth_stencil_opts.depth_write then TRUE else FALSE;
    depth_stencil_desc.DepthFunc   = cast(D3D11_COMPARISON_FUNC)depth_stencil_opts.depth_compare_func;

    check_result(device.CreateDepthStencilState(device, *depth_stencil_desc, *pipeline.depth_stencil_state));

    // blend mode
    // (note it is valid in OMSetBlendState for blend_state to be null)
    if blend_mode != .Default {
        using blend_desc: D3D11_BLEND_DESC;
        RenderTarget[0] = .{
            BlendEnable = TRUE,
            SrcBlend = .D3D11_BLEND_SRC_ALPHA,
            DestBlend = .D3D11_BLEND_INV_SRC_ALPHA,
            BlendOp = .D3D11_BLEND_OP_ADD,
            SrcBlendAlpha = .D3D11_BLEND_ONE,
            DestBlendAlpha = .D3D11_BLEND_ZERO,
            BlendOpAlpha = .D3D11_BLEND_OP_ADD,
            RenderTargetWriteMask = 0x0f,
        };
        check_result(device.CreateBlendState(device, *blend_desc, *pipeline.blend_state));
    }

    return pipeline;
}

apply_pipeline :: (pipeline: *Pipeline) {
    assert_state();

    device_context := cast(*ID3D11DeviceContext)renderer.device_context1;

    using pipeline;

    device_context.IASetPrimitiveTopology(device_context, primitive_type);
    device_context.IASetInputLayout(device_context, shader.input_layout);

    device_context.VSSetShader(device_context, shader.vert, null, 0);
    device_context.RSSetState(device_context, xx rasterizer_state);

    device_context.PSSetShader(device_context, shader.frag, null, 0);

    device_context.OMSetDepthStencilState(device_context, depth_stencil_state, 0);

    blend_factors :: float.[ 1, 1, 1, 1 ];
    device_context.OMSetBlendState(device_context, blend_state, *blend_factors, 0xffffffff);
}

apply_viewport :: (x: float = 0, y: float = 0, width: float = -1, height: float = -1) {
    if width == -1 || height == -1 {
        if renderer.current_pass != null {
            color := renderer.current_pass.color[0];
            assert(color != null);
            if width == -1  width = cast(float)color.width;
            if height == -1 height = cast(float)color.height;
        } else {
            if width == -1 width = cast(float)renderer.depth_buffer_desc.Width;
            if height == -1 height = cast(float)renderer.depth_buffer_desc.Height;
        }
    }

    assert(width > 0);
    assert(height > 0);

    // TODO: multiple viewports
    viewport: D3D11_VIEWPORT;
    viewport.TopLeftX = x;
    viewport.TopLeftY = y;
    viewport.Width = width;
    viewport.Height = height;
    viewport.MinDepth = 0;
    viewport.MaxDepth = 1;
    
    renderer.device_context1.RSSetViewports(xx renderer.device_context1, 1, *viewport);
}

apply_constant_buffers :: (constant_buffers: ..*Buffer) {
    assert_state();
    device_context := cast(*ID3D11DeviceContext)renderer.device_context1;

    buffers: [..]*ID3D11Buffer;
    buffers.allocator = __temporary_allocator;
    for constant_buffers array_add(*buffers, it.d3d_buffer);

    device_context.VSSetConstantBuffers(device_context, 0, cast(u32)buffers.count, buffers.data);
}

load_texture_from_file :: (filename: string) -> bool, Texture {
    renderer := assert_state();

    bitmap: Bitmap;

    force_channels:s32 = 4; // TODO: texture compression instead of RGBA everything!

    if !bitmap_load(*bitmap, filename, requested_bytes_per_pixel = force_channels)
        return false, .{};

    assert(bitmap.width > 0);
    assert(bitmap.height > 0);

    ok, tex := load_texture_from_data(cast(u32)bitmap.width, cast(u32)bitmap.height, xx force_channels, bitmap.data, debug_name=filename);
    tex.debug_name = copy_string(filename);
    return ok, tex;
}

load_texture_from_data :: (width: u32, height: u32, bytes_per_pixel: u32, data: *void, debug_name: string) -> bool, Texture {
    renderer := assert_state();

    textureDesc := D3D11_TEXTURE2D_DESC.{
        MipLevels          = 1,
        ArraySize          = 1,
        SampleDesc.Count   = 1,
        Usage              = .D3D11_USAGE_IMMUTABLE,
        BindFlags          = .D3D11_BIND_SHADER_RESOURCE,
    };

    if bytes_per_pixel == {
        case 4; textureDesc.Format = .DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
        case; assert(false);
    }

    textureDesc.Width  = width;
    textureDesc.Height = height;

    textureData: D3D11_SUBRESOURCE_DATA;
    textureData.pSysMem            = data;
    textureData.SysMemPitch        = width * bytes_per_pixel;

    tex: Texture;
    tex.width  = cast(u16)width;
    tex.height = cast(u16)height;
    tex.debug_name = copy_string(debug_name);

    unload_and_return_error :: () #expand {
        unload_texture(*tex);
        return false, .{};
    }

    device := cast(*ID3D11Device)renderer.device;
    {
        res := device.CreateTexture2D(device, *textureDesc, *textureData, *tex.texture2D);
        if res != S_OK {
            flush_errors();
            unload_and_return_error();
        }
    }
    {
        view: *ID3D11ShaderResourceView;
        res := device.CreateShaderResourceView(device, xx tex.texture2D, null, *view);
        if res != S_OK {
            flush_errors();
            unload_and_return_error();
        }
        array_add(*tex.views, view);
    }

    // Sampler
    sampler_desc := D3D11_SAMPLER_DESC.{
        Filter         = .D3D11_FILTER_MIN_MAG_MIP_POINT,
        AddressU       = .D3D11_TEXTURE_ADDRESS_WRAP,
        AddressV       = .D3D11_TEXTURE_ADDRESS_WRAP,
        AddressW       = .D3D11_TEXTURE_ADDRESS_WRAP,
        ComparisonFunc = .D3D11_COMPARISON_NEVER,
    };
    {
        res := device.CreateSamplerState(device, *sampler_desc, *tex.sampler_state);
        if res != S_OK || tex.sampler_state == null {
            flush_errors();
            unload_and_return_error();
        }
    }

    return true, tex;
}

unload_texture :: (texture: *Texture) {
    print("TODO: impl unload texture\n");
}


find_fxc :: () -> string {
    return "c:\\Program Files (x86)\\Windows Kits\\10\\bin\\10.0.19041.0\\x64\\fxc.exe";
}

get_temporary_filename :: () -> string {
    kernel32 :: #foreign_system_library "kernel32";
    GetTempPathW     :: (buffer_length_in_tchars: u32, buffer: *u16) -> u32 #foreign kernel32;
    GetTempFileNameW :: (path_name: *u16, prefix_string: *u16, unique: u32, temp_filename: *u16) -> u32 #foreign kernel32;

    path_name: [MAX_PATH + 1]u16;
    num_tchars := GetTempPathW(MAX_PATH + 1, path_name.data);
    assert(num_tchars > 0);

    temp_filename: [MAX_PATH + 1]u16;
    res := GetTempFileNameW(path_name.data, utf8_to_wide("shd"), 0, temp_filename.data);
    assert(res != 0);

    return wide_to_utf8(temp_filename.data);
}

run_fxc_on_string :: (shader_string: string, target_profile: string, entrypoint_name: string) -> (compiled_blob: string) {
    assert(shader_string.count > 0);
    tempfile := get_temporary_filename();
    write_entire_file(tempfile, shader_string);
    defer file_delete(tempfile);
    return run_fxc(tempfile, target_profile, entrypoint_name);
}

// fxc is the directx command line HLSL compiler.
run_fxc :: (filename: string, target_profile: string, entrypoint_name: string) -> (compiled_blob: string) {
    temp_file := tprint("temp.%.%.cso", target_profile, entrypoint_name);

    file_delete(temp_file);

    args: [..]string;
    args.allocator = __temporary_allocator;
    array_add(*args, find_fxc(), "/nologo");
    //array_add(*args, "/Od", "/Zi");
    array_add(*args, "/O3");
    array_add(*args, "/T", target_profile);
    array_add(*args, "/E", entrypoint_name);
    array_add(*args, "/Fo", temp_file);
    array_add(*args, filename);

    print("%\n", join(..args, separator = " "));

    successfully_launched, exit_code, output_string, error_string := os_run_command(..args);

    if !successfully_launched || exit_code != 0
        compiler_report(#file, #line, 0, tprint("Error (launched=%, exit_code=%) from fxc shader compiler.\n%\n%",
            successfully_launched, exit_code, error_string, output_string));

    blob_bytes, success := read_entire_file(temp_file);
    if !success
        compiler_report(#file, #line, 0, tprint("Did not find fxc output shader blob at '%'\n", temp_file));

    file_delete(temp_file);

    return blob_bytes;
}

load_shader_from_file :: ($filename: string, $vs_main := "vs_main", $ps_main := "ps_main") -> (ok: bool, shader: Shader) {
    #if #run get_build_options().optimization_level != .RELEASE {
        ok, shader := _load_shader_from_file_at_runtime(filename, vs_main, ps_main);
        return ok, shader;
    } else {
        vs_blob_str := #run run_fxc(filename, "vs_5_0", vs_main);
        ps_blob_str := #run run_fxc(filename, "ps_5_0", ps_main);
        assert(vs_blob_str.count > 0);
        assert(ps_blob_str.count > 0);
        assert(vs_blob_str != ps_blob_str);
        vs_blob := create_d3d_blob_from_str(vs_blob_str);
        ps_blob := create_d3d_blob_from_str(ps_blob_str);
        ok, shader := load_shader_from_blobs(vs_blob, ps_blob);
        return ok, shader;
    }
}

_compile_shader_at_runtime :: (filename: string, target_profile: string, entrypoint_name: string) -> (ok: bool, blob: *ID3DBlob) {
    assert(filename.count > 0);
    filename_w := utf8_to_wide(filename);

    shader_blob, error_blob: *ID3DBlob;
    logprint("renderer", "compiling shader % in % (%)", entrypoint_name, filename, target_profile);
    if S_OK != D3DCompileFromFile(filename_w, null, null, tprint("%\0", entrypoint_name).data, tprint("%\0", target_profile).data, 0, 0, *shader_blob, *error_blob) {
        flush_errors();
        logprint("shader", "D3DCompileFromFile(%, %) failed...\n%", entrypoint_name, filename, blob_to_string(error_blob));
        Release(error_blob);
        return false, null;
    }

    assert(shader_blob != null);
    return true, shader_blob;
}

_load_shader_from_file_at_runtime :: (filename: string, vs_main := "vs_main", ps_main := "ps_main") -> (ok: bool, shader: Shader) {
    renderer := assert_state();
    vs_ok, vs_blob := _compile_shader_at_runtime(filename, "vs_5_0", vs_main);
    if !vs_ok return false, .{};
    ps_ok, ps_blob := _compile_shader_at_runtime(filename, "ps_5_0", ps_main);
    if !ps_ok return false, .{};
    // @Leak ....defer release blobs?
    ok, shader := load_shader_from_blobs(vs_blob, ps_blob);
    return ok, shader;
}

load_shader_from_blobs :: (compiled_vs_blob: *ID3DBlob, compiled_ps_blob: *ID3DBlob) -> (bool, Shader) {
    renderer := assert_state();

    using shader: Shader;
    shader.vs_blob = compiled_vs_blob;
    shader.ps_blob = compiled_ps_blob;
    device := renderer.device;

    unload_and_return_shader_error :: (message := "", args: ..Any) #expand {
        if message.count > 0 logprint("shader", tprint("%\n", message), ..args);
        unload_shader(*shader);
        return false, .{};
    }

    {
        res := device.CreateVertexShader(cast(*ID3D11Device)device, vs_blob.GetBufferPointer(vs_blob), vs_blob.GetBufferSize(vs_blob), null, *vert);
        if res != S_OK || vert == null {
            flush_errors();
            unload_and_return_shader_error("CreateVertexShader failed\n");
        }
    }

    if 1 {
        res := CreateInputLayoutDescFromVertexShaderSignature(vs_blob, cast(*ID3D11Device)device, *input_layout, *input_layout_byte_length);
        if res != S_OK || input_layout == null {
            flush_errors();
            unload_and_return_shader_error("CreateInputLayoutDescFromVertexShaderSignature failed");
        }
    }

    {
        res := device.CreatePixelShader(cast(*ID3D11Device)device, ps_blob.GetBufferPointer(ps_blob), ps_blob.GetBufferSize(ps_blob), null, *frag);
        if res != S_OK || frag == null {
            flush_errors();
            unload_and_return_shader_error("CreatePixelShader failed");
        }
    }

    return true, shader;
}

_get_swapchain_framebuffer :: (using renderer: *Renderer) {
    assert(renderer.swap_chain != null);

    // frame buffer
    check_result(swap_chain.GetBuffer(cast(*IDXGISwapChain)swap_chain, 0, *uid(ID3D11Texture2D.uuid), cast(**void)*frame_buffer));
    assert(frame_buffer != null);

    // render target view
    check_result(device.CreateRenderTargetView(cast(*ID3D11Device)device, cast(*ID3D11Resource)frame_buffer, null, *frame_buffer_view));
    assert(frame_buffer_view != null);

    // depth buffer
    frame_buffer.GetDesc(frame_buffer, *depth_buffer_desc);
    depth_buffer_desc.Format    = .DXGI_FORMAT_D24_UNORM_S8_UINT;
    depth_buffer_desc.BindFlags = .D3D11_BIND_DEPTH_STENCIL;

    check_result(device.CreateTexture2D(cast(*ID3D11Device)device, *depth_buffer_desc, null, *depth_buffer));
    assert(depth_buffer != null);

    check_result(device.CreateDepthStencilView(cast(*ID3D11Device)device, cast(*ID3D11Resource)depth_buffer, null, *depth_buffer_view));
    assert(depth_buffer_view != null);
}

init_from_main_window :: (main_renderer: *Renderer, new_renderer_ptr: *Renderer, hwnd: HWND, debug := true) {
    assert(main_renderer != null);
    assert(new_renderer_ptr != null);

    new_renderer_ptr.device = main_renderer.device;
    new_renderer_ptr.device_context1 = main_renderer.device_context1;

    // we'll make a new swap chain
    init(new_renderer_ptr, hwnd, debug);
}

set_context :: (renderer_ptr: *Renderer) {
    renderer = renderer_ptr;
}

init :: (renderer_ptr: *Renderer, hwnd: HWND, debug := true) {
    set_context(renderer_ptr);

    base_device: *ID3D11Device;
    base_device_context: *ID3D11DeviceContext;

    create_device_flags := D3D11_CREATE_DEVICE_FLAGS.D3D11_CREATE_DEVICE_BGRA_SUPPORT;

    if debug
        create_device_flags |= .D3D11_CREATE_DEVICE_DEBUG;

    feature_levels := D3D_FEATURE_LEVEL.[ .D3D_FEATURE_LEVEL_11_1 ];
    check_result(D3D11CreateDevice(null, .D3D_DRIVER_TYPE_HARDWARE, null, create_device_flags, feature_levels.data,
            feature_levels.count, D3D11_SDK_VERSION, *base_device, null, *base_device_context));

    debug_info_queue: *ID3D11InfoQueue;
    if debug {
        // Get the debug queue interface for retreiving warning/error messages
        // if the debug layer is on.
        check_result(base_device.QueryInterface(cast(*IUnknown)base_device, *uid("6543dbb6-1b48-42f5-ab82-e97ec74326f6"), cast(**void)*debug_info_queue));
        debug_info_queue.PushEmptyRetrievalFilter(xx debug_info_queue);
    }

    if renderer.device == null {
        check_result(base_device.QueryInterface(xx base_device, *uid(ID3D11Device1.uuid), cast(**void)*renderer.device));
    }
    if renderer.device_context1 == null {
        check_result(base_device_context.QueryInterface(xx base_device_context, *uid(ID3D11DeviceContext1.uuid), cast(**void)*renderer.device_context1));
    }

    dxgi_device: *IDXGIDevice1;
    check_result(renderer.device.QueryInterface(xx renderer.device, *uid(IDXGIDevice1.uuid), cast(**void)*dxgi_device));
    defer Release(dxgi_device);

    dxgi_adapter: *IDXGIAdapter;
    dxgi_device.GetAdapter(cast(*IDXGIDevice)dxgi_device, *dxgi_adapter);
    assert(dxgi_adapter != null);
    defer Release(dxgi_adapter);

    dxgi_factory: *IDXGIFactory2;
    dxgi_adapter.GetParent(cast(*IDXGIObject)dxgi_adapter, *uid(IDXGIFactory2.uuid), cast(**void)*dxgi_factory);
    assert(dxgi_factory != null, "no IDXGIFactory2 returned");
    defer Release(dxgi_factory);

    swap_chain_desc := DXGI_SWAP_CHAIN_DESC1.{
        Width  = 0, // use window width
        Height = 0, // use window height
        Format = .DXGI_FORMAT_B8G8R8A8_UNORM_SRGB,
        Stereo = FALSE,
        SampleDesc = .{
            Count   = 1,
            Quality = 0,
        },
        BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
        BufferCount = 2,
        Scaling     = .DXGI_SCALING_STRETCH,
        SwapEffect  = .DXGI_SWAP_EFFECT_DISCARD,
        AlphaMode   = .DXGI_ALPHA_MODE_UNSPECIFIED,
        Flags       = 0,
    };

    swap_chain: *IDXGISwapChain1;
    check_result(dxgi_factory.CreateSwapChainForHwnd(dxgi_factory, cast(*IUnknown)renderer.device, hwnd, *swap_chain_desc, null, null, *swap_chain));
    assert(swap_chain != null, "CreateSwapChainForHwnd did not create a swap chain!");
    renderer.swap_chain = swap_chain;

    _get_swapchain_framebuffer(renderer);


    // TODO: move all this up into the function
    renderer.debug_info_queue = debug_info_queue;

    // generate utility textures

    // TODO: move this into a shared init thing

    SZ :: 16;
    {
        pixels: [SZ * SZ]u32;
        
        tex_ok: bool;

        for 0..(SZ*SZ)-1 pixels[it] = 0xffffffff;
        tex_ok, renderer.white_texture = load_texture_from_data(SZ, SZ, 4, pixels.data, debug_name = "white_texture");
        assert(tex_ok);
    }
}

present :: () {
    using renderer := assert_state();
    swap_chain.Present(cast(*IDXGISwapChain)swap_chain, 1, 0);
    flush_debug_messages();
}

flush_errors :: () {
    print_stack_trace(context.stack_trace);
    flush_debug_messages();
}

flush_debug_messages :: () {
    using renderer := assert_state();

    if !debug_info_queue
        return;

    message_count := debug_info_queue.GetNumStoredMessages(debug_info_queue);
    if message_count == 0
        return;

    did_have_message := false;

    for i: 0 .. message_count - 1 {
        auto_release_temp();

        message_size: u64;
        debug_info_queue.GetMessage(debug_info_queue, i, null, *message_size); //get the size of the message

        message := cast(*D3D11_MESSAGE)talloc(cast(s64)message_size);
        check_result(debug_info_queue.GetMessage(debug_info_queue, i, message, *message_size)); //get the actual message

        str: string;
        str.data = message.pDescription;
        // This byte length seems to include the null byte, so we'll make the
        // string count one less.
        str.count = cast(s64)message.DescriptionByteLength - 1; 

        if debug_message_callback != null {
            debug_message: Debug_Message;
            debug_message.severity = cast(Debug_Message.Severity)message.Severity;
            debug_message.text     = str;
            debug_message_callback(debug_message);
        } else {
            print("%\n", str);
        }

        did_have_message = true;
    }

    if did_have_message
        print_stack_trace(context.stack_trace);

    debug_info_queue.ClearStoredMessages(debug_info_queue);
}

get_buffer_ptr :: (buffer: *Buffer, ptr: **$T) #expand {
    using renderer := assert_state();
    assert(buffer != null);
    assert(buffer.d3d_buffer != null);
    mapped_subresource: D3D11_MAPPED_SUBRESOURCE;
    subresource_index :: 0;
    check_result(device_context1.Map(xx device_context1, xx buffer.d3d_buffer, subresource_index, .D3D11_MAP_WRITE_DISCARD, 0, *mapped_subresource));
    assert(mapped_subresource.pData != null);
    `defer device_context1.Unmap(xx device_context1, xx buffer.d3d_buffer, 0);

    <<ptr = cast(*T)mapped_subresource.pData;
}

get_constant_buffer_ptr :: (ptr: **$T, buffer: *Buffer) #expand {
    assert_state();
    assert(buffer != null);
    constant_buffer := buffer.d3d_buffer;
    mappedSubresource: D3D11_MAPPED_SUBRESOURCE;
    subresource_index :: 0;
    check_result(renderer.device_context1.Map(xx renderer.device_context1, xx constant_buffer, subresource_index, .D3D11_MAP_WRITE_DISCARD, 0, *mappedSubresource));
    assert(mappedSubresource.pData != null);
    `defer renderer.device_context1.Unmap(xx renderer.device_context1, xx constant_buffer, 0);

    <<ptr = cast(*T)mappedSubresource.pData;
}

next_multiple_of :: (N: int, X: int) -> int {
    // X is the number you want to round up to the nearest multiple N
    return ((N - 1) | (X - 1)) + 1;
}

set_global_renderer_ptr :: (new_renderer: *Renderer) {
    renderer = new_renderer;
}


#scope_file

CreateInputLayoutDescFromVertexShaderSignature :: (pShaderBlob: *ID3DBlob, pD3DDevice: *ID3D11Device, pInputLayout: **ID3D11InputLayout, inputLayoutByteLength: *u32) -> HRESULT {
    pVertexShaderReflection: *ID3D11ShaderReflection;
    if S_OK != D3DReflect(pShaderBlob.GetBufferPointer(pShaderBlob), pShaderBlob.GetBufferSize(pShaderBlob), *uid(ID3D11ShaderReflection.uuid), cast(**void)*pVertexShaderReflection) {
        flush_errors();
        return S_FALSE;
    }
    defer Release(pVertexShaderReflection);
     
    // get shader description
    shaderDesc: D3D11_SHADER_DESC;
    #assert(size_of(D3D11_SHADER_DESC) == 160);
    assert(size_of(D3D11_SIGNATURE_PARAMETER_DESC) == 40, tprint("expected 40, got %", size_of(D3D11_SIGNATURE_PARAMETER_DESC)));
    pVertexShaderReflection.GetDesc(pVertexShaderReflection, *shaderDesc);
     
    // Read input layout description from shader info
    byteOffset:u32 = 0;
    inputLayoutDesc: [..]D3D11_INPUT_ELEMENT_DESC;
    inputLayoutDesc.allocator = __temporary_allocator;
    
    // TODO: the compiler is only showing one input parameter without this...
    //print("Number of InputParameters: %\n", shaderDesc.InputParameters);

    for i: 0..shaderDesc.BoundResources {
        input_bind_desc: D3D11_SHADER_INPUT_BIND_DESC;
        pVertexShaderReflection.GetResourceBindingDesc(pVertexShaderReflection, i, *input_bind_desc);
        //print("input_bind_desc %: %\n%\n", i, to_string(input_bind_desc.Name), input_bind_desc);
    }
    
    for i: 0..shaderDesc.InputParameters - 1 {
        paramDesc: D3D11_SIGNATURE_PARAMETER_DESC;
        pVertexShaderReflection.GetInputParameterDesc(pVertexShaderReflection, i, *paramDesc);
 
        elementDesc: D3D11_INPUT_ELEMENT_DESC;  
        elementDesc.SemanticName = paramDesc.SemanticName;      
        elementDesc.SemanticIndex = paramDesc.SemanticIndex;
        elementDesc.InputSlot = 0;
        elementDesc.AlignedByteOffset = byteOffset;
        elementDesc.InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
        elementDesc.InstanceDataStepRate = 0;  
 
        // determine DXGI format
        if paramDesc.Mask == 1 {
            if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_UINT32 elementDesc.Format = DXGI_FORMAT_R32_UINT;
            else if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_SINT32 elementDesc.Format = DXGI_FORMAT_R32_SINT;
            else if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_FLOAT32 elementDesc.Format = DXGI_FORMAT_R32_FLOAT;
            byteOffset += 4;
        } else if paramDesc.Mask <= 3 {
            if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_UINT32 elementDesc.Format = DXGI_FORMAT_R32G32_UINT;
            else if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_SINT32 elementDesc.Format = DXGI_FORMAT_R32G32_SINT;
            else if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_FLOAT32 elementDesc.Format = DXGI_FORMAT_R32G32_FLOAT;
            byteOffset += 8;
        } else if paramDesc.Mask <= 7 {
            if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_UINT32 elementDesc.Format = DXGI_FORMAT_R32G32B32_UINT;
            else if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_SINT32 elementDesc.Format = DXGI_FORMAT_R32G32B32_SINT;
            else if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_FLOAT32 elementDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
            byteOffset += 12;
        } else if paramDesc.Mask <= 15 {
            if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_UINT32 elementDesc.Format = DXGI_FORMAT_R32G32B32A32_UINT;
            else if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_SINT32 elementDesc.Format = DXGI_FORMAT_R32G32B32A32_SINT;
            else if paramDesc.ComponentType == .D3D_REGISTER_COMPONENT_FLOAT32 elementDesc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
            byteOffset += 16;
        } else {
            assert(false);
        }
             
        array_add(*inputLayoutDesc, elementDesc);
    }

    hr := pD3DDevice.CreateInputLayout(pD3DDevice, inputLayoutDesc.data, cast(u32)inputLayoutDesc.count, pShaderBlob.GetBufferPointer(pShaderBlob), pShaderBlob.GetBufferSize(pShaderBlob), pInputLayout);
 
    // record byte length
    if inputLayoutByteLength != null {
        <<inputLayoutByteLength = byteOffset;
    }
 
    return hr;
}

assert_state :: inline () -> *Renderer {
    assert(renderer != null, "must call init(*renderer) first");
    return renderer;
}

Release :: inline (ptr: *$T) { // IUnknown Release, checks for null
    if ptr != null
        ptr.Release(cast(*IUnknown)ptr);
}

blob_to_string :: (blob: *ID3DBlob) -> string { // only lives as long as the blob
    if blob == null
        return "";

    str: string;
    str.data  = blob.GetBufferPointer(xx blob);
    str.count = cast(s64)blob.GetBufferSize(xx blob);
    return str;
}

create_d3d_blob_from_str :: (blob_bytes: string) -> *ID3DBlob {
    assert(blob_bytes.count > 0);
    blob: *ID3DBlob;
    check_result(D3DCreateBlob(cast(u64)blob_bytes.count, *blob));
    assert(blob != null);
    memcpy(blob.GetBufferPointer(blob), blob_bytes.data, blob_bytes.count);
    return blob;
}





renderer: *Renderer;

#import "Bitmap";
#import "Render/Texture_Format";

#import "d3d11";
#import "Basic";
#import "Math";
#import "Windows_Utf8";
#import "D3dcompiler";
#import "dxgi";
#import "Windows";
#import "d3d11_shader"; // for shader reflection
#import "d3d11_1";      // for 11_1 features

// these are for the compile-time shader FXC compiler
#import "File";
#import "Process";
#import "Compiler";
#import "String";
#import "Build_Constants";
#import "math_extra";
