UI_State :: struct {
    using ui_state_base: UI_State_Base;

    d3dDevice: *ID3D11Device;
    d3dDeviceContext: *ID3D11DeviceContext;
    Factory: *IDXGIFactory;
    VB: *ID3D11Buffer;
    IB: *ID3D11Buffer;
    VertexShader: *ID3D11VertexShader;
    InputLayout: *ID3D11InputLayout;
    VertexConstantBuffer: *ID3D11Buffer;
    PixelShader: *ID3D11PixelShader;
    FontSampler: *ID3D11SamplerState;
    FontTextureView: *ID3D11ShaderResourceView;
    RasterizerState: *ID3D11RasterizerState;
    BlendState: *ID3D11BlendState;
    DepthStencilState: *ID3D11DepthStencilState;
    VertexBufferSize: s32 = 5000;
    IndexBufferSize: s32 = 10000;
}

ImGui_ImplDX11_SetupRenderState :: (using ui_state: *UI_State, draw_data: *ImDrawData) {
    d_ctx := ui_state.d3dDeviceContext;

    // Setup viewport
    vp: D3D11_VIEWPORT;
    vp.Width = draw_data.DisplaySize.x;
    vp.Height = draw_data.DisplaySize.y;
    vp.MinDepth = 0.0;
    vp.MaxDepth = 1.0;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    d_ctx.RSSetViewports(d_ctx, 1, *vp);

    // Setup shader and vertex buffers
    stride:u32 = size_of(ImDrawVert);
    offset:u32 = 0;
    d_ctx.IASetInputLayout(d_ctx, InputLayout);
    d_ctx.IASetVertexBuffers(d_ctx, 0, 1, *VB, *stride, *offset);
    idx_buf_type := ifx size_of(ImDrawIdx) == 2 then DXGI_FORMAT_R16_UINT else DXGI_FORMAT_R32_UINT;
    d_ctx.IASetIndexBuffer(d_ctx, IB, idx_buf_type, 0);
    d_ctx.IASetPrimitiveTopology(d_ctx, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    d_ctx.VSSetShader(d_ctx, VertexShader, null, 0);
    d_ctx.VSSetConstantBuffers(d_ctx, 0, 1, *VertexConstantBuffer);
    d_ctx.PSSetShader(d_ctx, PixelShader, null, 0);
    d_ctx.PSSetSamplers(d_ctx, 0, 1, *FontSampler);
    d_ctx.GSSetShader(d_ctx, null, null, 0);
    d_ctx.HSSetShader(d_ctx, null, null, 0); // In theory we should backup and restore this as well.. very infrequently used..
    d_ctx.DSSetShader(d_ctx, null, null, 0); // In theory we should backup and restore this as well.. very infrequently used..
    d_ctx.CSSetShader(d_ctx, null, null, 0); // In theory we should backup and restore this as well.. very infrequently used..

    // Setup blend state
    blend_factor : [4]float = .[0, 0, 0, 0];
    d_ctx.OMSetBlendState(d_ctx, BlendState, blend_factor, 0xffffffff);
    d_ctx.OMSetDepthStencilState(d_ctx, DepthStencilState, 0);
    d_ctx.RSSetState(d_ctx, RasterizerState);
}

ImGui_Impl_RenderDrawData :: (using ui_state: *UI_State, draw_data: *ImGui.ImDrawData) {
    // Avoid rendering when minimized
    if draw_data.DisplaySize.x <= 0 || draw_data.DisplaySize.y <= 0
        return;

    d_ctx := ui_state.d3dDeviceContext;

    // Create and grow vertex/index buffers if needed
    if !VB || VertexBufferSize < draw_data.TotalVtxCount {
        if VB != null { VB.Release(xx VB); VB = null; }
        VertexBufferSize = draw_data.TotalVtxCount + 5000;
        desc := D3D11_BUFFER_DESC.{
            Usage = .D3D11_USAGE_DYNAMIC,
            BindFlags = .D3D11_BIND_VERTEX_BUFFER,
            CPUAccessFlags = .D3D11_CPU_ACCESS_WRITE,
            MiscFlags = 0,
        };
        desc.ByteWidth = cast(u32)(VertexBufferSize * size_of(ImDrawVert));
        if d3dDevice.CreateBuffer(d3dDevice, *desc, null, *VB) < 0 {
            logprint("imgui_d3d11", "Error creating the vertex buffer");
            return;
        }
    }

    if !IB || IndexBufferSize < draw_data.TotalIdxCount {
        if IB != null { IB.Release(xx IB); IB = null; }
        IndexBufferSize = draw_data.TotalIdxCount + 10000;
        desc := D3D11_BUFFER_DESC.{
            Usage = D3D11_USAGE_DYNAMIC,
            BindFlags = D3D11_BIND_INDEX_BUFFER,
            CPUAccessFlags = D3D11_CPU_ACCESS_WRITE,
        };
        desc.ByteWidth = cast(u32)(IndexBufferSize * size_of(ImDrawIdx));
        if d3dDevice.CreateBuffer(d3dDevice, *desc, null, *IB) < 0 {
            logprint("imgui_d3d11", "Error creating the index buffer");
            return;
        }
    }

    // Upload vertex/index data into a single contiguous GPU buffer
    vtx_resource, idx_resource: D3D11_MAPPED_SUBRESOURCE;
    if d_ctx.Map(xx d_ctx, xx VB, 0, .D3D11_MAP_WRITE_DISCARD, 0, *vtx_resource) != S_OK
        return;
    if d_ctx.Map(xx d_ctx, xx IB, 0, .D3D11_MAP_WRITE_DISCARD, 0, *idx_resource) != S_OK
        return;

    vtx_dst := cast(*ImDrawVert)vtx_resource.pData;
    idx_dst := cast(*ImDrawIdx)idx_resource.pData;
    for n: 0..draw_data.CmdListsCount - 1 {
        cmd_list := draw_data.CmdLists[n];
        memcpy(vtx_dst, cmd_list.VtxBuffer.Data, cmd_list.VtxBuffer.Size * size_of(ImDrawVert));
        memcpy(idx_dst, cmd_list.IdxBuffer.Data, cmd_list.IdxBuffer.Size * size_of(ImDrawIdx));
        vtx_dst += cmd_list.VtxBuffer.Size;
        idx_dst += cmd_list.IdxBuffer.Size;
    }
    d_ctx.Unmap(xx d_ctx, xx VB, 0);
    d_ctx.Unmap(xx d_ctx, xx IB, 0);

    // Setup orthographic projection matrix into our constant buffer
    // Our visible imgui space lies from draw_data.DisplayPos (top left) to draw_data.DisplayPos+data_data.DisplaySize (bottom right). DisplayPos is (0,0) for single viewport apps.
    {
        mapped_resource: D3D11_MAPPED_SUBRESOURCE;
        if d_ctx.Map(xx d_ctx, xx VertexConstantBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, *mapped_resource) != S_OK
            return;

        VERTEX_CONSTANT_BUFFER :: struct {
            mvp: [4][4]float;
        }

        constant_buffer := cast(*VERTEX_CONSTANT_BUFFER)mapped_resource.pData;
        L:float = draw_data.DisplayPos.x;
        R:float = draw_data.DisplayPos.x + draw_data.DisplaySize.x;
        T:float = draw_data.DisplayPos.y;
        B:float = draw_data.DisplayPos.y + draw_data.DisplaySize.y;
        make_float4 :: (a: float, b: float, c: float, d: float) -> [4]float {
            f: [4]float = ---;
            f[0] = a;
            f[1] = b;
            f[2] = c;
            f[3] = d;
            return f;
        }
        mvp: [4][4]float;
        mvp[0] = make_float4(2.0/(R-L),   0.0,           0.0,       0.0 );
        mvp[1] = make_float4(0.0,         2.0/(T-B),     0.0,       0.0 );
        mvp[2] = make_float4(0.0,         0.0,           0.5,       0.0 );
        mvp[3] = make_float4((R+L)/(L-R),  (T+B)/(B-T),  0.5,       1.0 );
        memcpy(*constant_buffer.mvp, mvp[0].data, size_of(type_of(mvp)));
        d_ctx.Unmap(xx d_ctx, xx VertexConstantBuffer, 0);
    }

    // Backup DX state that will be modified to restore it afterwards (unfortunately this is very ugly looking and verbose. Close your eyes!)
    BACKUP_DX11_STATE :: struct {
        ScissorRectsCount: u32;
        ViewportsCount: u32;
        ScissorRects: [D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE]D3D11_RECT;
        Viewports: [D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE]D3D11_VIEWPORT;
        RS: *ID3D11RasterizerState;
        BlendState: *ID3D11BlendState;
        BlendFactor: [4]float;
        SampleMask: u32;
        StencilRef: u32;
        DepthStencilState: *ID3D11DepthStencilState;
        PSShaderResource: *ID3D11ShaderResourceView;
        PSSampler: *ID3D11SamplerState;
        PS: *ID3D11PixelShader;
        VS: *ID3D11VertexShader;
        GS: *ID3D11GeometryShader;
        PSInstancesCount: u32;
        VSInstancesCount: u32;
        GSInstancesCount: u32;
        PSInstances: [256]*ID3D11ClassInstance;
        VSInstances: [256]*ID3D11ClassInstance;
        GSInstances: [256]*ID3D11ClassInstance;   // 256 is max according to PSSetShader documentation
        PrimitiveTopology: D3D11_PRIMITIVE_TOPOLOGY;
        IndexBuffer: *ID3D11Buffer;
        VertexBuffer: *ID3D11Buffer;
        VSConstantBuffer: *ID3D11Buffer;
        IndexBufferOffset: u32;
        VertexBufferStride: u32;
        VertexBufferOffset: u32;
        IndexBufferFormat: DXGI_FORMAT;
        InputLayout: *ID3D11InputLayout;
    };

    old: BACKUP_DX11_STATE;
    old.ScissorRectsCount = D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE;
    old.ViewportsCount = D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE;
    d_ctx.RSGetScissorRects(d_ctx, *old.ScissorRectsCount, old.ScissorRects.data);
    d_ctx.RSGetViewports(d_ctx, *old.ViewportsCount, old.Viewports.data);
    d_ctx.RSGetState(d_ctx, *old.RS);
    d_ctx.OMGetBlendState(d_ctx, *old.BlendState, old.BlendFactor, *old.SampleMask);
    d_ctx.OMGetDepthStencilState(d_ctx, *old.DepthStencilState, *old.StencilRef);
    d_ctx.PSGetShaderResources(d_ctx, 0, 1, *old.PSShaderResource);
    d_ctx.PSGetSamplers(d_ctx, 0, 1, *old.PSSampler);
    old.PSInstancesCount = 256;
    old.VSInstancesCount = 256;
    old.GSInstancesCount = 256;
    d_ctx.PSGetShader(d_ctx, *old.PS, old.PSInstances.data, *old.PSInstancesCount);
    d_ctx.VSGetShader(d_ctx, *old.VS, old.VSInstances.data, *old.VSInstancesCount);
    d_ctx.VSGetConstantBuffers(d_ctx, 0, 1, *old.VSConstantBuffer);
    d_ctx.GSGetShader(d_ctx, *old.GS, old.GSInstances.data, *old.GSInstancesCount);

    d_ctx.IAGetPrimitiveTopology(d_ctx, *old.PrimitiveTopology);
    d_ctx.IAGetIndexBuffer(d_ctx, *old.IndexBuffer, *old.IndexBufferFormat, *old.IndexBufferOffset);
    d_ctx.IAGetVertexBuffers(d_ctx, 0, 1, *old.VertexBuffer, *old.VertexBufferStride, *old.VertexBufferOffset);
    d_ctx.IAGetInputLayout(d_ctx, *old.InputLayout);

    // Setup desired DX state
    ImGui_ImplDX11_SetupRenderState(ui_state, draw_data);

    // Render command lists
    // (Because we merged all buffers into a single one, we maintain our own offset into them)
    global_idx_offset:u32 = 0;
    global_vtx_offset:u32 = 0;
    clip_off := draw_data.DisplayPos;
    for n: 0..draw_data.CmdListsCount - 1 {
        cmd_list := draw_data.CmdLists[n];
        for cmd_i: 0..cmd_list.CmdBuffer.Size - 1 {
            pcmd := *cmd_list.CmdBuffer.Data[cmd_i];
            if pcmd.UserCallback != null {
                // User callback, registered via ImDrawList::AddCallback()
                // (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
                ImDrawCallback_ResetRenderState :: -1;
                if cast(int)cast(*void)pcmd.UserCallback == ImDrawCallback_ResetRenderState
                    ImGui_ImplDX11_SetupRenderState(ui_state, draw_data);
                else
                    pcmd.UserCallback(cmd_list, pcmd);
            } else {
                // Apply scissor/clipping rectangle
                r: D3D11_RECT;
                r.left   = cast(s32)(pcmd.ClipRect.x - clip_off.x);
                r.top    = cast(s32)(pcmd.ClipRect.y - clip_off.y);
                r.right  = cast(s32)(pcmd.ClipRect.z - clip_off.x);
                r.bottom = cast(s32)(pcmd.ClipRect.w - clip_off.y);
                d_ctx.RSSetScissorRects(d_ctx, 1, *r);

                // Bind texture, Draw
                texture_srv := cast(*ID3D11ShaderResourceView)pcmd.TextureId;
                d_ctx.PSSetShaderResources(d_ctx, 0, 1, *texture_srv);
                d_ctx.DrawIndexed(d_ctx, pcmd.ElemCount, pcmd.IdxOffset + global_idx_offset, cast(s32)(pcmd.VtxOffset + global_vtx_offset));
            }
        }
        global_idx_offset += cast(u32)cmd_list.IdxBuffer.Size;
        global_vtx_offset += cast(u32)cmd_list.VtxBuffer.Size;
    }

    // Restore modified DX state
    d_ctx.RSSetScissorRects(d_ctx, old.ScissorRectsCount, old.ScissorRects.data);
    d_ctx.RSSetViewports(d_ctx, old.ViewportsCount, old.Viewports.data);
    d_ctx.RSSetState(d_ctx, old.RS); Release(old.RS);
    d_ctx.OMSetBlendState(d_ctx, old.BlendState, old.BlendFactor, old.SampleMask); Release(old.BlendState);
    d_ctx.OMSetDepthStencilState(d_ctx, old.DepthStencilState, old.StencilRef); Release(old.DepthStencilState);
    d_ctx.PSSetShaderResources(d_ctx, 0, 1, *old.PSShaderResource); Release(old.PSShaderResource);
    d_ctx.PSSetSamplers(d_ctx, 0, 1, *old.PSSampler); Release(old.PSSampler);
    d_ctx.PSSetShader(d_ctx, old.PS, old.PSInstances.data, old.PSInstancesCount); Release(old.PS);
    for i: 0..old.PSInstancesCount - 1 if old.PSInstances[i] Release(old.PSInstances[i]);
    d_ctx.VSSetShader(d_ctx, old.VS, old.VSInstances.data, old.VSInstancesCount); Release(old.VS);
    d_ctx.VSSetConstantBuffers(d_ctx, 0, 1, *old.VSConstantBuffer); Release(old.VSConstantBuffer);
    d_ctx.GSSetShader(d_ctx, old.GS, old.GSInstances.data, old.GSInstancesCount); Release(old.GS);
    for i: 0..old.VSInstancesCount - 1 if old.VSInstances[i] Release(old.VSInstances[i]);
    d_ctx.IASetPrimitiveTopology(d_ctx, old.PrimitiveTopology);
    d_ctx.IASetIndexBuffer(d_ctx, old.IndexBuffer, old.IndexBufferFormat, old.IndexBufferOffset); Release(old.IndexBuffer);
    d_ctx.IASetVertexBuffers(d_ctx, 0, 1, *old.VertexBuffer, *old.VertexBufferStride, *old.VertexBufferOffset); Release(old.VertexBuffer);
    d_ctx.IASetInputLayout(d_ctx, old.InputLayout); Release(old.InputLayout);
}

ImGui_Impl_SetupGLContext :: () {
}

ImGui_SetMouseEvents :: (using ui_state: *UI_State, left: bool, middle: bool, right: bool, wheel: float) {
    MousePressed[0] = left;
    MousePressed[1] = right;
    MousePressed[2] = middle;
    MouseWheel = wheel;
}

ImGui_Impl_NewFrame :: (ui_state: *UI_State, native_window_handle: *void, display_width: s32, display_height: s32) {
}

ImGui_Impl_Init :: (using ui_state: *UI_State, native_window_handle: *void) -> bool {
    return false;
}


#load "imgui_impl_common.jai";

#scope_file

ImDrawVert :: ImGui.ImDrawVert;
ImDrawData :: ImGui.ImDrawData;
ImDrawIdx :: ImGui.ImDrawIdx;

Release :: inline (ptr: *$T) {
    if ptr != null
        ptr.Release(cast(*IUnknown)ptr);
}

#import "d3d11";
#import "dxgi";
#import "Windows";
S_OK :: 0;
