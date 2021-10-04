/*

# how to avoid the unity play mode/edit mode dichotomy?

## first - play mode / edit mode is USEFUL 
It lets you try out changes, and then revert them, or keep them so we don't want to lose that, at least.

*BUT.* the thing we want *in addition* is to quickly move between play and edit...without breaking flow. In the platformer, being able to jump around, see a problem, and fix it, or add a new thing, and then go back to playing the level, all without losing context. THAT sounds like something worth trying to do.

Maybe the whole idea of separating edit and play mode is holding us back.

--

how do "changes" work in the editor compared to unity?
or are these questions too early? instead it might be good
to focus in on this particular game. or at least to think
about building editor tools that can be plugged into different
projects, instead of a monolithic friend

still: inspirations:
     - mario maker
        - easy transition from one mode to another
        - player follows the editor camera around?

pause the game as is, or reset it back? --
     i think a major difference could be that some
     entities could be maintained. for example, if the player
     state survives through a playmode->editmode->playmode transition
     then you can be playing, editing, playing in a one flow
     
     so at first, it could be that game state is divided into
     "survives editmode" and "doesn't survive editmode" states.

     another possibility could be that you can "pause" and enter edit mode
     but edit a prefab for something on screen, like an enemy.
     then you could see the enemy midpose, and modify its parameters

     it might also be useful to have a "show idle animations" mode
     during edit mode. or maybe that's the default?
    
timers are key:
    player timer can keep going
    maybe timers have a bitflag, and the editor can control which ones tick forward

editing a prefab

    idea: animate the changes from a prefab to the current instance to show the difference
    use the animation to "go back" to the prefab when you zoom in on it
*/

Undo :: #import "undo";

Editor :: struct {
    undo_state: Undo.Impl;

    scene_camera: Camera; // editor view camera

    wants_keyboard: bool;

    tweens: Tweens;

    selector_filter: ImGui.TextFilter;

    play_mode: Play_Mode = .Edit;
    fading_to_play: bool;
    fading_alpha: float = 1;

    callbacks: struct {
        did_drag: #type (rect: rl.Rectangle);
    };

    drag_state: struct {
        dragging: bool;
        origin:   Vector2;
        edge:     Drag_Edge;
    };

    selected: [..]Selected_Object;
    hover: Maybe(Entity_Handle);
    tentative_hover_click: Maybe(Entity_Handle);

    editing_entity_name: Maybe(Entity_Handle);
    editing_entity_grab_focus := false;

    world_mouse_pos: Vector3;
    mouse_pos: Latch(Vector2);

    last_click_time: float64 = -99999; // nocheckin

    assets: [..]Asset;
    selected_asset: *Asset = null;

    last_loaded_scene_filename: string; @owned

    wait_for_entity_name: Maybe(Entity_Handle);
    wait_for_entity_name_time: float64;

    entities_window_size: ImGui.ImVec2;

    is_mouse_looking := false;

    pending_scene_load: struct {
        filename: string; @owned
        state: enum {
            None;
            Waiting;
        }
    };

    scene_view_rect: rl.Rectangle;
    mouse_is_over_scene_view: bool;
    mouse_over_scene_view_window: bool;

    show_main_menu: bool = false;
    show_aspect_ratio_guide := true;

    windows: struct {
        inspector      := true;
        imgui_demo     := false;
        entities       := true;
        assets         := true;
        new_assets     := true;
        screenlog      := true;
        undo_internals := false;
        prefab_cache   := false;
        ecs_internals  := false;
        context_inspector := false;
        asset_selector: struct {
            filter: ImGui.TextFilter;
            visible := false;
            selected_asset_type: Asset.Type;
            selected_asset: union {
                tex: *LiveTexture;
                shader: *Shader;
            };
        };
        gamepad_viz    := false;
        profiler       := true;
        scene_view     := true;
        todo           := false;
        about          := false;
    };

    inspector_has_focus: bool;

    todos: Todos_State;

    grid: Grid.State;
}

Asset :: struct {
    Type :: enum u32 {
        Prefab  :: 1;
        Texture :: 2;
        Sprite  :: 3;
        Shader  :: 4;
    }

    type: Type;
    filename: string;
    short_name: string;
    filetime: u64;
    union {
        live_texture: LiveTexture;
        live_sprite: LiveSprite;
        live_shader: *Shader;
    }
}

Play_Mode :: enum {
    Play;
    Edit;
}

Vec2 :: Vector2;

Selected_Object :: struct {
    using handle: Entity_Handle;
    original_pos: Vector2;
    original_scale: Vector2;
}

InputTextStr :: (str: *string) -> bool {
    MAX_SIZE :: 200;
    assert(str.count < MAX_SIZE);

    buf := cast(*u8)talloc(MAX_SIZE + 1);
    memcpy(buf, str.data, str.count);
    buf[str.count] = #char "\0";

    res:bool = ImGui.InputText("", buf, MAX_SIZE);
    if res {
        new_len := c_style_strlen(buf);
        
        // @Leak
        // @Leak
        // @Leak
        // @Leak
        // @Leak
        // @Leak
        // @Leak
        // @Leak

        if new_len != str.count {
            str.data = alloc(new_len); // @Leak
            str.count = new_len;
        }

        memcpy(str.data, buf, new_len);
    }

    return res;
}


categorize_type :: (ti: *Type_Info) -> Struct_Looks_Like {
    // TODO: this should just go away and merge with `custom_ctrl` below.
    if ti == type_info(rl.Color)
        return .Color_Byte4;
    else if ti == type_info(Quaternion)
        return .Has_Custom_Control;
    else if ti == type_info(Entity_Handle)
        return .Has_Custom_Control;
    else if ti == type_info(LiveTexture)
        return .Has_Custom_Control;
    else if ti == type_info(*Shader)
        return .Has_Custom_Control;
    else if false && ti == type_info(Transform)
        return .Has_Custom_Control;
    return .None;
}

custom_ctrl :: (name: string, data: *void, ti: *Type_Info) {
    using ImGui;

    if ti == type_info(Entity_Handle)
        entity_selector(name, cast(*Entity_Handle)data);
    else if ti == type_info(Quaternion) {
        quat := cast(*Quaternion)data;
        euler := euler_angles(<<quat);
        if DragFloat3(temp_c_string(name), cast(*[3]float)*euler) {
            <<quat = quaternion_from_euler(euler);
        }
        push_or_commit_item(data, size_of(Quaternion));
    }
    else if ti == type_info(LiveTexture) 
        live_image_editor(cast(*LiveTexture)data);
    else if ti == type_info(*Shader)
        live_shader_editor(name, cast(**Shader)data);
    else if false && ti == type_info(Transform) {

        /*
        TODO it would be nice to have the metaprogram notice an "editor" function like this...

        inspect_transform :: (transform: *Transform) { 
            // and then automatically call them all here...
        } @inspector
        */

        // roll, pitch, yaw

        copysign :: (x: $A, y: A) -> A {
          if (x < 0 && y > 0) || (x > 0 && y < 0)
            return -x;
          return x;
        }

        quaternion_to_euler :: (q: Vector4) -> Vector3 {
            angles: Vector3;

            // roll (x-axis rotation)
            sinr_cosp := 2.0 * (q.w * q.x + q.y * q.z);
            cosr_cosp := 1.0 - 2.0 * (q.x * q.x + q.y * q.y);
            angles.x = atan2(sinr_cosp, cosr_cosp);

            // pitch (y-axis rotation)
            sinp := 2.0 * (q.w * q.y - q.z * q.x);
            if abs(sinp) >= 1
                angles.y = copysign(PI / 2.0, sinp); // use 90 degrees if out of range
            else
                angles.y = asin(sinp);

            // yaw (z-axis rotation)
            siny_cosp := 2 * (q.w * q.z + q.x * q.y);
            cosy_cosp := 1 - 2 * (q.y * q.y + q.z * q.z);
            angles.z = atan2(siny_cosp, cosy_cosp);

            return angles;
        }

        euler_to_quaternion :: (yaw: float, pitch: float, roll: float) -> Vector4 { // yaw (Z), pitch (Y), roll (X)
            // Abbreviations for the various angular functions
            cy := cos(yaw * 0.5);
            sy := sin(yaw * 0.5);
            cp := cos(pitch * 0.5);
            sp := sin(pitch * 0.5);
            cr := cos(roll * 0.5);
            sr := sin(roll * 0.5);

            q: Vector4;
            q.w = cr * cp * cy + sr * sp * sy;
            q.x = sr * cp * cy - cr * sp * sy;
            q.y = cr * sp * cy + sr * cp * sy;
            q.z = cr * cp * sy - sr * sp * cy;

            return q;
        }

        xrs := cast(*Transform)data;
        DragFloat3("pos", cast(*[3]float)*xrs.position);
        DragFloat3("scl", cast(*[3]float)*xrs.scale);

        quat := cast(*Vector4)*xrs.rotation;
        euler := quaternion_to_euler(<<quat);
        if DragFloat3("rotation", cast(*[3]float)*euler.x) {
            <<quat = euler_to_quaternion(euler.x, euler.y, euler.z);
            log("changed euler % to quat %", euler, <<quat);
        }

        DragFloat4("quat", cast(*[4]float)quat);
    }
}

live_shader_editor :: (name: string, live_shader: **Shader) {
    using ImGui;

    if <<live_shader == null {
        PushPopID("null shader");
        if Button("No Shader Selected")
            set_asset_selector_visible(live_shader);
    } else {
        if Button("TODO: shadername here") {
            set_asset_selector_visible(live_shader);
            SetWindowFocus(ASSET_SELECTOR_WINDOW_NAME);
        }
        SameLine();
        TextUnformatted(name);
    }
}

live_image_editor :: (live_texture_ptr: *LiveTexture) {
    using ImGui;

    if live_texture_ptr == null {
        Text("NULL");
        return;
    }

    live_texture := <<live_texture_ptr;
    if !has_value(live_texture) {
        PushPopID("null image");
        if Button("No Image Selected")
            set_asset_selector_visible(live_texture_ptr);
    } else {
        PushPopStyleColor(.Button, .{0, 0, 0, 0});
        tex_id, size := imtex(live_texture_ptr);
        PushPopID(tex_id);
        MAX_HEIGHT :: 150;
        if size.y > MAX_HEIGHT {
            size.x /= size.y / MAX_HEIGHT;
            size.y /= size.y / MAX_HEIGHT;
        }
        if ImageButton(tex_id, size) {
            set_asset_selector_visible(live_texture_ptr);
        }
    }

    // Allow user to drop colors into each palette entry. Note that ColorButton() is already a
    // drag source by default, unless specifying the ImGuiColorEditFlags_NoDragDrop flag.
    if BeginDragDropTarget() {
        defer EndDragDropTarget();

        /*
        if payload := AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F)
            memcpy((float*)*saved_palette[n], payload->Data, sizeof(float) * 3);
        if payload := AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F)
            memcpy((float*)*saved_palette[n], payload->Data, sizeof(float) * 4);
        */
    }
}

File_Visit_Info :: File_Utilities.File_Visit_Info;

file_list_infos :: (path: string, recursive := false, follow_symlinks := false) -> []File_Visit_Info #must {
    infos : [..] File_Visit_Info;
    visitor :: (info: *File_Visit_Info, user_data: *[..]File_Visit_Info) {
        info_copy := <<info;
        info_copy.short_name = copy_string(info.short_name);
        info_copy.full_name = copy_string(info.full_name);
        array_add(user_data, info_copy);
    }
    File_Utilities.visit_files(path, recursive, *infos, visitor, follow_symlinks=follow_symlinks);
    return infos;
}


look_rotation :: (forward: Vector3, up := Vector3.{0, 1, 0}) -> Quaternion {
    m := make_look_at_matrix(.{0, 0, 0}, forward, up, x_is_forward = false);
    return get_rotation(m);
}

editor_init :: (editor: *Editor) {
    {
        using editor;
        pos :: Vector3.{500, 300, -300};
        scene_camera.position = pos;
        target := pos;
        target.z = 0;
        //scene_camera.rotation = get_rotation(make_look_at_matrix(pos, target, reference_up_vector=Vector3.{0, 1, 0}, x_is_forward = false));
        scene_camera.matrices_need_update = true;
    }

    copy_File_Visit_Info :: (asset: *Asset, file_visit_info: File_Visit_Info) {
        asset.filename = file_visit_info.full_name;
        asset.short_name = file_visit_info.short_name;
        asset.filetime = file_visit_info.filetime;
    }

    for file_list_infos("prefabs", recursive=true) {
        asset := array_add(*editor.assets);
        asset.type = .Prefab;
        copy_File_Visit_Info(asset, it);
    }

    for file_list_infos("resources", recursive=true) {
        ext := String.path_extension(it.full_name);
        asset: *Asset;
        if ext == "png" || ext == "jpg" {
            asset = array_add(*editor.assets);
            asset.type = .Texture;
        } else if ext == "aseprite" || ext == "ase" {
            asset = array_add(*editor.assets);
            asset.type = .Sprite;
        } else if ext == "fs" {
            asset = array_add(*editor.assets);
            asset.type = .Shader;
        } else {
            continue;
        }

        copy_File_Visit_Info(asset, it);
    }

    Grid.init(*editor.grid);
}

is_valid_drag_rect :: (rectangle: rl.Rectangle) -> bool {
    return rectangle.width > 5 || rectangle.height > 5;
}

editor_draw_world :: (state: *State) {
    using context.state.editor;

    if play_mode == .Play return;

    im_push_entity_handle(.{});

    if selected.count > 0 {
        for selected {
            ok, entity := get_entity(it);
            if !ok continue;
            rect, depth_z := entity_rect_and_depth(entity);
            rl.DrawRectangleLinesEx(entity_rect(entity), 2, rl.WHITE, depth_z = depth_z);
        }
    } else if drag_state.dragging {
        dragging_rect := rect_from_points(drag_state.origin, world_mouse_pos.xy);
        if is_valid_drag_rect(dragging_rect)
            rl.DrawRectangleLinesEx(dragging_rect, 3, rl.RED);
    }

    if hover.has_value {
        ok, entity := get_entity(hover, check_count = true);
        if ok {
            rect, depth_z := entity_rect_and_depth(entity);
            rl.DrawRectangleLinesEx(rect, 1, rl.Color.{200, 200, 255, 128}, depth_z = depth_z);
        }
    }

    screenp("drawing grid");
    calc_matrices(*scene_camera);
    Grid.draw(*grid, scene_camera.view_projection_matrix);
}

editor_draw :: (state: *State) {
    render_imgui_to_drawlists(state);
}

set_asset_selector_visible :: (live_texture_ptr: *LiveTexture) {
    using context.state.editor.windows.asset_selector;
    visible = true;
    selected_asset_type = .Texture;
    selected_asset.tex = live_texture_ptr;
}

set_asset_selector_visible :: (live_shader_ptr: **Shader) {
    using context.state.editor.windows.asset_selector;
    visible = true;
    selected_asset_type = .Shader;
    selected_asset.shader = <<live_shader_ptr;
}

ASSET_SELECTOR_WINDOW_NAME :: "Assets##Selector";

render_asset_selector :: (window_open: *bool) {
    BeginEnd_return(ASSET_SELECTOR_WINDOW_NAME, window_open);

    using ImGui;
    using context.state.editor.windows.asset_selector;
    TextFilter.Draw(*filter, "##asset selector filter text");

    assets: [..]*Asset;
    assets.allocator = __temporary_allocator;
    array_add(*assets, null);
    for * context.state.editor.assets
        array_add(*assets, it);
        
    for assets {
        filename_z := "None";
        if it != null {
            sans_ext := String.path_strip_extension(it.short_name);
            filename_z = temp_c_string_obj(sans_ext);

            if it.type != selected_asset_type || !TextFilter.PassFilter(*filter, filename_z)
                continue;

            // TODO: this is requesting we load the image. we should probably
            // have a background task, or a "pending image loads" queue or
            // something...
            if it.type == .Texture && !has_value(it.live_texture) {
                it.live_texture = LoadLiveTexture(it.filename);
            }
        }

        if selected_asset_type == {
        case .Texture;
            live_tex := selected_asset.tex;
            selected_tex_id, selected_tex_size := imtex(live_tex);
            empty_live_tex: LiveTexture;
            entry_tex := ifx it == null then *empty_live_tex else *it.live_texture;
            tex_id, size := imtex(entry_tex, ImGui.make_ImVec2(MAX_HEIGHT, MAX_HEIGHT));
            MAX_HEIGHT :: 200;
            if size.y > MAX_HEIGHT {
                size.x /= size.y / MAX_HEIGHT;
                size.y /= size.y / MAX_HEIGHT;
            }

            selected := tex_id == selected_tex_id;

            if !selected PushStyleColor(.Button, .{0, 0, 0, 0});
            defer { if !selected PopStyleColor(); }

            {
                PushGroup();
                if ImageButton(tex_id, size) {
                    Undo.push(*context.state.editor.undo_state, live_tex);
                    <<live_tex = <<entry_tex;
                    Undo.commit(*context.state.editor.undo_state);
                }
                Text(filename_z.data);
            }
            SameLine();
        case .Shader;
            label: string;
            if it == null {
                label = "None";
            } else {
                label = it.short_name;
            }
            live_shader := selected_asset.shader;
            PushPopID(live_shader);
            if Button(temp_c_string(label)) {
                if it == null {
                    selected_asset.shader = null;
                } else {
                    log_error("TODO: change shader");
                    //<<selected_asset.shader = LoadLiveShader("", it.filename);
                }
            }
        }
    }
}

edit_entity_name :: (handle: Entity_Handle) {
    using context.state.editor;

    editing_entity_name.has_value = true;
    editing_entity_name.value = handle;
    editing_entity_grab_focus = true;
}

get_scene_view_size :: () -> Vector2_u16 {
    using context.state.editor;

    if play_mode == .Play {
        return framebuffer_size();
    } else {
        sz: Vector2_u16;
        sz.x = cast(u16)scene_view_rect.width;
        sz.y = cast(u16)scene_view_rect.height;
        return sz;
    }
}

get_scene_view_screen_mouse_pos :: () -> Vector2 {
    using context.state.editor;
    mouse_x, mouse_y := platform.get_client_mouse_pos(_local_host_state.window_handle);
    pos := v2(mouse_x, mouse_y);
    pos -= scene_view_rect.position;
    return pos;
}

render_imgui_to_drawlists :: (state: *State) {
    using state;
    using ImGui;

    set_play_mode_later: bool;
    defer if set_play_mode_later {
        state.editor.play_mode = .Play;
    }

    {
        // Fade the editor in and out when toggling between edit and play mode.
        using state.editor;
        if play_mode == .Edit {
            ALPHA_CHANGE_SPEED :: 11.0;
            if fading_to_play {
                fading_alpha -= Time.unscaled_delta_time * ALPHA_CHANGE_SPEED;
                if fading_alpha <= 0 {
                    fading_to_play = false;
                    fading_alpha = 0;
                    set_play_mode_later = true;
                }
            } else if fading_alpha < 1 {
                fading_alpha = clamp(fading_alpha + Time.unscaled_delta_time * ALPHA_CHANGE_SPEED, 0, 1);
            }
        }
    }

    // the screen log always shows, even in playmode
    {
        using state.editor;
        if windows.screenlog show_screen_log(*windows.screenlog);
    }

    // Overlay showing compiler error
    has_compile_error, err_str := get_plugin_compile_error();
    if has_compile_error {
        {
            DISTANCE:float = 80.0;
            viewport         := GetMainViewport();
            work_area_pos    := viewport.WorkPos;
            work_area_size   := viewport.WorkSize;
            window_pos       := ImGui.make_ImVec2(work_area_pos.x + DISTANCE, work_area_pos.y + DISTANCE);
            window_pos_pivot := ImGui.make_ImVec2(0, 0);
            SetNextWindowPos(window_pos, .Always, window_pos_pivot);
            SetNextWindowViewport(viewport.ID_);
        }
        SetNextWindowBgAlpha(0.99); // Transparent background
        window_flags :: ImGui.WindowFlags.NoDecoration | .NoMove | .NoDocking | .AlwaysAutoResize | .NoSavedSettings | .NoFocusOnAppearing | .NoNav;
        defer End();
        if Begin("compiler error overlay", null, window_flags) {
            if err_str.count > 0 {
                PushPopFont(context.state.ui.monospace_font);
                PushTextWrapPos(ImGui.GetFontSize() * 55.0);
                Text(temp_c_string(err_str));
            }
        }
    }

    defer {
        if state.editor.show_aspect_ratio_guide
            draw_lkg_aspect_overlay(GetForegroundDrawList());
    }

    if state.editor.play_mode == .Play {
        show_scene_view(*context.state.editor.windows.scene_view, in_play_mode=true);
        return;
    }

    PushPopStyleVar(.Alpha, editor.fading_alpha); // from here on out, we may be fading out the entire editor. when going to play mode

    {
        window_flags :: ImGui.WindowFlags.NoDocking | .NoTitleBar | .NoCollapse
            | .NoResize | .NoMove | .NoBringToFrontOnFocus | .NoNavFocus |
            .NoBackground;

        viewport := GetMainViewport();
        SetNextWindowPos(viewport.WorkPos);
        SetNextWindowSize(viewport.WorkSize);
        SetNextWindowViewport(viewport.ID_);
        PushStyleVar(.WindowRounding, 0);
        PushStyleVar(.WindowBorderSize, 0);
        {
            open := true;
            PushStyleVar(.WindowPadding, ImGui.make_ImVec2(0, 0));
            Begin("DockSpace Demo", *open, window_flags);
            PopStyleVar();
            show_menubar();
            defer End();
            PopStyleVar(2);
            assert(GetIO().ConfigFlags_ & .DockingEnable != 0);
            DockSpace(GetID("Main DockSpace"), .{}, DockNodeFlags.PassthruCentralNode);
            if editor.mouse_is_over_scene_view && editor.mouse_over_scene_view_window && want_mouselook() // TODO: only change the cursor when the mouse is over the "scene"
                SetMouseCursor(.ResizeAll);
        }
    }


    if editor.windows.ecs_internals {
        defer End();
        if Begin("DEBUG", *editor.windows.ecs_internals)
            inspect("internals", *state.world.entities.items, categorize_type_func=categorize_type, custom_ctrl=custom_ctrl);
    }

    using editor;
    if windows.prefab_cache {
        defer End();
        if Begin("prefab cache", *windows.prefab_cache)
            inspect("", *context.state.world.prefab_cache);
    }
    
    if windows.imgui_demo     ImGui.ShowDemoWindow(*windows.imgui_demo);
    if windows.undo_internals show_undo_internals(*windows.undo_internals);
    if windows.new_assets     show_new_assets_window(*windows.new_assets);
    if windows.assets         show_assets_window(*windows.assets);
    if windows.entities       show_entities_window(*windows.entities);
    if windows.inspector      draw_inspector(*windows.inspector);
    if windows.gamepad_viz    show_gamepad_window(*windows.gamepad_viz);
    if windows.profiler       show_profiler_window(*windows.profiler);
    if windows.scene_view     show_scene_view(*windows.scene_view);
    if windows.todo           show_todo_window(*windows.todo);
    if windows.about          show_about_window(*windows.about);

    if windows.asset_selector.visible render_asset_selector(*windows.asset_selector.visible);

    save_changes_modal();
}

draw_lkg_aspect_overlay :: (draw_list: *ImGui.ImDrawList) {
    using context.state.editor;
    using ImGui;

    LKG_ASP :: 0.75;

    asp := cast(float)scene_view_rect.width / cast(float)scene_view_rect.height;

    p1, p2: ImVec2;
    if asp > LKG_ASP {
        // center a rectangle in the sceneview rect, but with the aspect
        // ratio of the looking glass
        p1.y = scene_view_rect.y;
        p2.y = scene_view_rect.height + scene_view_rect.y;

        center_x := scene_view_rect.x + scene_view_rect.width*0.5;
        w2 := scene_view_rect.height * LKG_ASP * 0.5;

        p1.x = center_x - w2;
        p2.x = center_x + w2;
    } else {
        // TODO
    }

    draw_list.AddRect(draw_list, p1, p2, make_col32(make_ImVec4(0.2, 0.2, 0.2, 0.5)), rounding=20);
}

NUM_SAVE_SLOTS :: 8;

show_menubar :: () {
    using context.state.editor;
    using ImGui;

    if !show_main_menu || !BeginMainMenuBar() return;
    defer EndMainMenuBar();

    BeginEndMenu("File", #code {
        BeginEndMenu("Load Slot", #code {
            for i: 1..NUM_SAVE_SLOTS if MenuItem(tprint("Load Slot %\0", i).data)
                load_scene_confirming(scene_filename_for_slot(i));
        });
        BeginEndMenu("Save Slot", #code {
            for i: 1..NUM_SAVE_SLOTS if MenuItem(tprint("Save Slot %\0", i).data)
                save_scene(scene_filename_for_slot(i));
        });

        Separator();
        if MenuItem("Quit")
            _local_host_state.change_window_state(.Request_Application_Quit);
    });

    BeginEndMenu("Edit", #code {
        if MenuItem("Align Object to View", null, null, selected.count > 0)
            align_all_selected_objects_with_scene_view();
    });

    BeginEndMenu("View", #code {
        MenuItem("Show LKG-Portrait Aspect Ratio Guide", null, *show_aspect_ratio_guide);
        Separator();
        MenuItem("Show Main Menu", null, *show_main_menu);
        Separator();
        MenuItem("ImGui Demo Window", null, *windows.imgui_demo);
        MenuItem("About", null, *windows.about);
    });
}

align_all_selected_objects_with_scene_view :: () {
    using context.state.editor;

    cam := scene_camera;

    for selected {
        transform := get_transform(it.handle);
        if transform == null continue;

        Undo.push_scope(*undo_state, *transform.position, *transform.scale);
        transform.position = cam.position;
        transform.rotation = cam.rotation;
        // no scale change
    }
}

#load "todo_list.jai";

show_about_window :: (open: *bool) {
    using ImGui;
    BeginEnd_return("About", open);

    Text("unnamed game engine");
    Text("by Kevin Watters <kevinwatters@gmail.com>");

    Separator();

    if CollapsingHeader("Build Configuration")
        return;

    bool_str :: (b: bool) -> *s8 #expand {
        if b return "true";
        else return "false";
    }
    PushPopFont(context.state.ui.small_font);
    // TODO: generate a table to use here in metaprogram_common
    BulletText("DEBUG_MODULE :: %s", bool_str(DEBUG_MODULE));
    BulletText("GUARD_ALLOCATOR :: %s", bool_str(GUARD_ALLOCATOR));
    BulletText("BUILDING_DLLS :: %s", bool_str(BUILDING_DLLS));
    BulletText("GRAPHICS_LAYER_DEBUG :: %s", bool_str(GRAPHICS_LAYER_DEBUG));
}

show_todo_window :: (open: *bool) {
    using ImGui;

    BeginEnd_return("TODO", open);
    TextUnformatted("TODO");
    Separator();

    todos_state := *context.state.editor.todos;

    items := get_todos(todos_state);
    if items.count {
        for * items {
            checked: bool = it.state == .Complete;
            if Checkbox(tprint("##%\0", it.text).data, *checked) {
                if checked  {
                    it.state = .Complete;
                } else {
                    it.state = .Incomplete;
                }
                save_todo(todos_state, it);
            }
            SameLine();
            TextWrapped(tprint("%\0", it.text).data);
        }
    } else {
        PushPopStyleColor(.Text, .{.35, .35, .35, 1});
        TextUnformatted("(no items)");
    }

    just_opened := false;
    if Button(" + ") {
        OpenPopup("add_todo");
        just_opened = true;
    }

    center_next_window();
    if BeginPopupModal("add_todo", null, .AlwaysAutoResize) {
        defer EndPopup();

        TextUnformatted("Enter a new TODO:");
        did_hit_enter := InputText("##edit", input_buf.data, input_buf.count, flags=.EnterReturnsTrue);
        if just_opened SetKeyboardFocusHere(-1);

        if did_hit_enter || Button("OK", make_ImVec2(120, 0)) {
            add_todo(*context.state.editor.todos, to_string(input_buf.data));
            input_buf[0] = #char "\0";
            CloseCurrentPopup();
        }
        SameLine();
        if Button("Cancel", make_ImVec2(120, 0))
            CloseCurrentPopup();
    }
}

input_buf: [600]u8; // @Bloat // TODO: just put this in temp storage right?

show_scene_view :: (open: *bool, in_play_mode := false) {
    using ImGui;

    flags := WindowFlags.NoBackground;// | .NoInputs | .NoMouseInputs;
    if in_play_mode {
        flags |= WindowFlags.NoDecoration;
        SetNextWindowPos(GetMainViewport().Pos);
        SetNextWindowSize(GetMainViewport().Size);
    }

    PushPopStyleVar(.WindowPadding, ImGui.make_ImVec2(0, 0));
    defer End();
    if !Begin(tprint("Scene View##%\0", in_play_mode).data, open, flags) return;
    context.state.editor.mouse_over_scene_view_window = IsWindowHovered();

    scene_view_tex := *context.state.scene_view.color;
    Image(native_texture_imgui_id(scene_view_tex), make_ImVec2(xx scene_view_tex.width, xx scene_view_tex.height));

    // Store the position of the scene view window for later. The screen log
    // uses it to position itself on top.
    window_pos := GetWindowPos();
    vMin := GetWindowContentRegionMin() + window_pos;
    vMax := GetWindowContentRegionMax() + window_pos;
    {
        using context.state.editor;
        scene_view_rect.x = vMin.x;
        scene_view_rect.y = vMin.y;
        scene_view_rect.width  = vMax.x - vMin.x;
        scene_view_rect.height = vMax.y - vMin.y;
    }
}

show_profiler_window :: (open: *bool) {
    using context.state;
    using ImGui;
    
    BeginEnd_return("Profiler", open);
    if profiler_text.count > 0
        TextUnformatted(profiler_text);
    else
        TextUnformatted("No data.");
}

show_gamepad_window :: (open: *bool) {
    using context.state;
    using ImGui;

    BeginEnd_return("Gamepad", open);
    Gamepad :: #import "Gamepad";
    inspect("", *Gamepad.gamepad);
}

show_new_assets_window :: (open: *bool) {
    using ImGui;

    BeginEnd_return("Assets", open);
    if ButtonEx("Reimport All") {
        Assets.reimport_all();
    }
}

show_assets_window :: (open: *bool) {
    using context.state;
    using ImGui;

    BeginEnd_return("old assets", open);
    for * editor.assets {
        assert(it != null);
        PushPopID(it);

        //dnd := BeginDragDropSource();
        //defer { if dnd EndDragDropSource(); }
        //if dnd SetDragDropPayload("_ASSET", it, size_of(Asset));

        selected := editor.selected_asset == it;
        if Selectable(temp_c_string(String.path_strip_extension(it.short_name)), selected)
            editor.selected_asset = it;

        do_spawn := selected && IsItemHovered() && IsMouseDoubleClicked(0);
        do_edit_as_scene := false;

        if BeginPopupContextItem("asset context menu") {
            defer EndPopup();
            editor.selected_asset = it;
            if Selectable("Spawn in scene")
                do_spawn = true;
            if Selectable("Edit as scene")
                do_edit_as_scene = true;
        }

        if do_spawn {
            pos: Vector3 = editor.scene_camera.position;
            pos.z = 0;

            entity_handle: Entity_Handle;
            entity: *Entity;
            offset: Vector2;

            if it.type == {
                case .Prefab;
                    entity, entity_handle = spawn_prefab_from_filename(it.filename, pos, undo=*editor.undo_state);
                    offset = entity_rect(entity).size * 0.5;

                case .Texture;
                    entity, entity_handle = create_entity(context.state.world, it.short_name, undo=*editor.undo_state, world_pos=pos);
                    img := add_component(entity_handle, Simple_Image_Renderer);
                    img.texture = LoadLiveTexture(it.filename);
                    offset = 0.5 * v2(img.texture.width, img.texture.height);

                case .Sprite;
                    entity, entity_handle := create_entity(get_world(), it.short_name, undo=*editor.undo_state, world_pos=pos);
                    spr := add_component(entity_handle, SpriteRenderer);
                    spr.sprite_anim = LoadLiveSprite(it.filename);
                    offset = 0.5 * entity_rect(entity_handle).size;

                case;
                    log_error("unhandled asset type %", it.type);
            }

            // Select the new object if we made one.
            if entity != null {
                trs := get_transform(entity_handle);
                if trs
                    trs.position.xy -= entity_rect(entity).size * 0.5;

                Undo.push_array(*editor.undo_state, *editor.selected);
                set_selected(entity_handle);
                Undo.commit(*editor.undo_state);
            }
        }

        if do_edit_as_scene {
            context.state.global_time_scale = 0;
            load_scene_confirming(it.filename);
        }
    }
}

show_undo_internals :: (open: *bool) {
    using context.state.editor;
    using ImGui;

    BeginEnd_return("Undo", open);
    if ButtonEx("Undo", enabled=Undo.can_undo(*undo_state))
        Undo.undo(*undo_state);

    SameLine();

    if ButtonEx("Redo", enabled=Undo.can_redo(*undo_state))
        Undo.redo(*undo_state);

    SetNextItemOpen(true);
    inspect("", *context.state.editor.undo_state);
}

show_entities_window :: (open: *bool) {
    using ImGui;
    using context.state;

    BeginEnd_return("Entities", open);
    PushFont(ui.small_font);
    if Button("New") {
        PopFont();
        entity_ptr, entity_handle := create_entity(undo=*editor.undo_state);
        set_selected(entity_handle);
        Undo.commit(*editor.undo_state);
    } else
        PopFont();

    //Text("%d total", count_items(*world.entities));

    PushPopStyleVar(.ItemSpacing, ImVec2.{0, 0});

    //if TreeNodeEx("Entities", .DefaultOpen) {
        //defer TreePop();

        node_clicked: Maybe(Entity_Handle);
        for handles(*world.entities) {
            parent := get_parent(it);
            if parent != .{}
                continue;

            flags := TreeNodeFlags.SpanAvailWidth;
            // flags |= .OpenOnArrow;
            flags |= .Leaf; /// MUST REMOVE .Leaf once we have parent entities!
            for * sel: editor.selected if sel.handle == it
                flags |= .Selected;

            ok, entity := get_entity(it);
            if !ok continue;

            PushPopID(entity);

            using editor;
            if editing_entity_name.has_value && editing_entity_name.value == it {
                // Inline text editor for the entity name. Use by clicking once to select, and then
                // single clicking again on an entity.
                if editing_entity_grab_focus {
                    editing_entity_grab_focus = false;
                    Undo.push_string(*undo_state, *entity.name);
                    SetKeyboardFocusHere();
                }

                InputTextStr(*entity.name);

                if IsItemDeactivated() {
                    editing_entity_grab_focus = false;
                    editing_entity_name.has_value = false;
                    Undo.commit(*undo_state);
                }
            } else {
                //dnd := BeginDragDropSource();
                //defer { if dnd EndDragDropSource(); }

                //if dnd SetDragDropPayload("_ENTITY", *it, size_of(Entity_Handle));
                ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());
                defer ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());

                //name_label := tprint("% - %\0", entity.name, child_count(it));
                name_label := temp_c_string(entity.name);
                if TreeNodeEx(entity, flags, name_label) {
                    defer TreePop();
                }
            }

            if BeginPopupContextItem("entity context menu") {
                defer EndPopup();
                if Selectable("Save as prefab") {
                    filename := tprint("prefabs/%.wbml", entity.name);
                    save_prefab(filename, *it);
                }
                if Selectable("Delete") {
                    destroy_entity(it, undo=*editor.undo_state);
                    Undo.commit(*editor.undo_state);
                }

                if Selectable("Make child") {
                    found, prev_sibling := get_previous_sibling(it);
                    if found {
                        set_parent(it, prev_sibling);
                        log("editor - make child: %\n", it);
                    }
                }
            }

            if IsItemClicked()
                set(*node_clicked, it);
        }
            

        using editor;
        if node_clicked.has_value {
            was_selected := selected.count == 1 && selected[0].handle == node_clicked.value;
            {
                editor_undo_push_selected();
                set_or_toggle_selected(node_clicked.value);
            }
            if IsMouseDoubleClicked(0) {
                focus_editor_camera_on_entity(node_clicked.value);
                clear(*wait_for_entity_name);
            } else if was_selected {
                set(*wait_for_entity_name, node_clicked.value);
                wait_for_entity_name_time = Time.now;
            }
        } else {
            if selected.count == 1 && eq(*wait_for_entity_name, selected[0].handle) && Time.now - wait_for_entity_name_time > 0.4 {
                clear(*wait_for_entity_name);
                edit_entity_name(selected[0].handle);
            }

            if IsMouseClicked(0) && IsWindowHovered() {
                editor_undo_push_selected();
                clear_selection();
            }
        }
    //}
}

show_screen_log :: (open: *bool) {
    using ImGui;
    using context.state;

    // we use a zero sized window and draw text manually using its foreground drawlist
    SetNextWindowPos(.{0, 0});
    SetNextWindowSize(.{0, 0});
    flags :: WindowFlags.NoDecoration | .NoInputs | .NoBackground | .NoMouseInputs;
    defer End();
    if !Begin("Screenlog", open, flags) return;

    PushPopStyleVar(.ItemSpacing, .{0,1});
    //PushPopFont(context.state.ui.small_font);
    PushPopFont(context.state.ui.monospace_font);

    logger_state := screenlog.get_context_state();

    pos: ImVec2;
    {
        PAD :: 10;
        pos.x = editor.scene_view_rect.x;
        pos.y = editor.scene_view_rect.y;
        pos.x += PAD;
        pos.y += PAD;
    }

    draw_list := GetForegroundDrawList();
    for logger_state.entries {
        if it.message.data == null || it.message.count == 0
            continue;
        
        alpha_factor: float = 1.0;
        FADE_TIME :: 0.1;
        if it.time < FADE_TIME alpha_factor = max(cast(float)0.0, cast(float)it.time) / FADE_TIME;

        alpha := cast(float)(it.time / 0.5);
        color: u32;
        if it.log_flags & .ERROR
            color = GetColorU32(make_ImVec4(1, 0, 0, alpha));
        else
            color = GetColorU32(.Text, alpha);

        ident := it.ident;
        if ident.count > 0 && ident[0] == #char "=" advance(*ident);

        begin: string;
        if ident.count > 0 {
            begin = tprint("[%] %", ident, it.message);
            draw_list.AddText(draw_list, pos, color, begin);
            // TODO
            // Make ImGui.CalcTextSize work and use it here to make the [ident]
            // part of the message white.
        } else {
            begin = tprint("%", it.message);
        }

        draw_list.AddText(draw_list, pos, color, begin);
        pos.y += GetTextLineHeightWithSpacing();
    }
}

Hovered_Entity :: struct {
    handle: Entity_Handle;
    uv: Vector2;
}

hovered_entity_handles :: () -> []Hovered_Entity {
    // returns valid entity handles underneath the mouse
    handles: [..]Hovered_Entity;
    handles.allocator = __temporary_allocator;

    handle: Entity_Handle;
    for get_hovered_entities(*context.state.im_context) {
        handle.id = it.entity_id;
        handle.generation = it.entity_generation;
        ok, entity := get_entity(handle, check_count = true);
        if ok {
            entry := array_add(*handles);
            entry.handle = handle;
            entry.uv = it.uv;
        }
    }

    return handles;
}

editor_state :: inline () -> *Editor { return *context.state.editor; }

is_selected :: (handle: Entity_Handle) -> bool {
    for editor_state().selected
        if handle == it.handle
            return true;

    return false;
}

Drag_Edge :: enum {
    None;
    North;
    NorthEast;
    East;
    SouthEast;
    South;
    SouthWest;
    West;
    NorthWest;
}

get_cursor_for_drag_edge :: (drag_mode: Drag_Edge) -> ImGui.MouseCursor {
    if drag_mode == {
        case .North; #through;
        case .South; return .ResizeNS;
            
        case .East; #through;
        case .West; return .ResizeEW;

        case .NorthWest; #through;
        case .SouthEast; return .ResizeNWSE;

        case .NorthEast; #through;
        case .SouthWest; return .ResizeNESW;

        case .None; return .Arrow;
        case;
            assert(false, "unknown drag_mode: %", drag_mode);
            return .Arrow;
    }
}

get_drag_edge :: (entity_handle: Entity_Handle, uv: Vector2) -> Drag_Edge {
    //scl := get_lossy_scale(entity_handle);
    scl := entity_rect(entity_handle).size;

    border := v2(4, 4);
    // TODO: need a multiplier with screen space here.
    border = v2(border.x / scl.x, border.y / scl.y);

    if uv.x < border.x && uv.y < border.y             return .NorthWest;
    if uv.x > (1 - border.x) && uv.y > (1 - border.y) return .SouthEast;
    if uv.x > (1 - border.x) && uv.y < border.y       return .NorthEast;
    if uv.x < border.x && uv.y > (1 - border.y)       return .SouthWest;

    if uv.y > (1.0 - border.y) return .South;
    if uv.y < border.y         return .North;
    if uv.x > (1.0 - border.x) return .East;
    if uv.x < border.x         return .West;

    return .None;
}

editor_update :: (state: *State) {
    using context.state.editor;

    screen_mouse_pos := get_scene_view_screen_mouse_pos();
    mouse_is_over_scene_view = screen_mouse_pos.x >= 0 && screen_mouse_pos.y > 0 && screen_mouse_pos.x < scene_view_rect.width && screen_mouse_pos.y < scene_view_rect.height;

    io := ImGui.GetIO();

    defer wants_keyboard = io.WantCaptureKeyboard;

    if play_mode == .Play return;

    ctrl_down := is_key_down(.CTRL);
    shift_down := is_key_down(.SHIFT);
    
    if !io.WantTextInput {
        if rl.IsKeyPressed(.KEY_P) {
            if context.state.global_time_scale > 0
                context.state.global_time_scale = 0;
            else
                context.state.global_time_scale = 1;
        }
        if rl.IsKeyPressed(.KEY_M) {
            log_error("todo: implement multiview toggling again");
            // context.state.multiview.enabled = !context.state.multiview.enabled;
        }
        if is_key_pressed(.ALT) && !show_main_menu {
            show_main_menu = true;
        }
    }

    // Move editor camera with WASD

    is_mouse_looking = !io.WantTextInput && ((mouse_is_over_scene_view && mouse_over_scene_view_window) || is_mouse_looking) && want_mouselook();

    if is_mouse_looking {
        update := false; // camera did move
        {
            // moving with WASD 
            editor_cam_speed := Vector3.{250, 250, 50};
            if is_key_down(.SHIFT) editor_cam_speed *= 2;

            input_dir: Vector3;
            if is_key_down(#char "D") input_dir.x += 1;
            if is_key_down(#char "A") input_dir.x -= 1;
            if is_key_down(#char "Q") input_dir.y += 1;
            if is_key_down(#char "E") input_dir.y -= 1;
            if is_key_down(#char "W") input_dir.z += 1;
            if is_key_down(#char "S") input_dir.z -= 1;

            if input_dir.x != 0 || input_dir.y != 0 || input_dir.z != 0 {
                input_dir   = normalize(input_dir);
                local_move := input_dir * editor_cam_speed * state.Time.unscaled_delta_time;

                // camera-relative direction vectors
                up      := rotate(Vector3.{0, 1, 0}, scene_camera.rotation);
                forward := rotate(Vector3.{0, 0, 1}, scene_camera.rotation);
                right   := rotate(Vector3.{1, 0, 0}, scene_camera.rotation);

                if !is_approximately_zero(input_dir.x) { scene_camera.position += local_move.x * right; update = true; }
                if !is_approximately_zero(input_dir.y) { scene_camera.position += local_move.y * up; update = true; }
                if !is_approximately_zero(input_dir.z) { scene_camera.position += local_move.z * forward; update = true; }
            }
        }

        {
            // rotation with mouse delta
            mouse_rotate_speed :: 0.16;
            if _local_host_state.mouse_delta.x != 0 || _local_host_state.mouse_delta.y != 0 {
                #if 1 {
                    rotate_delta := mouse_rotate_speed * make_vector3(
                        // TODO: why are these backwards?
                        -cast(float)_local_host_state.mouse_delta.y,
                         cast(float)_local_host_state.mouse_delta.x,
                        0);

                    x: Quaternion; set_from_axis_and_angle(*x, Vector3.{1, 0, 0}, rotate_delta.x * TO_RADIANS);
                    y: Quaternion; set_from_axis_and_angle(*y, Vector3.{0, 1, 0}, rotate_delta.y * TO_RADIANS);
                    z: Quaternion; set_from_axis_and_angle(*z, Vector3.{0, 0, 1}, rotate_delta.z * TO_RADIANS);

                    temp := z * y * x * scene_camera.rotation;
                    normalize_or_identity(*temp);
                    scene_camera.rotation = temp;

                    euler := euler_angles(scene_camera.rotation);
                    euler.z = 0;
                    screenp("euler %", euler);
                    scene_camera.rotation = quaternion_from_euler(euler);

                } else {
                    euler := euler_angles(scene_camera.rotation);
                    euler.y += _local_host_state.mouse_delta.x;
                    euler.x -= _local_host_state.mouse_delta.y;
                    //log("mouse_delta %", _local_host_state.mouse_delta);
                    scene_camera.rotation = quaternion_from_euler(euler);
                }
                update = true;
            }
        }


        if update {
            scene_camera.matrices_need_update = true;
        }
    }

    if mouse_is_over_scene_view && mouse_over_scene_view_window { // don't let imgui clicks come through to this one.
        {
            // mouse wheel zoom
            if _local_host_state.mouse_delta.z != 0 {
                scene_camera.fov += cast(float)_local_host_state.mouse_delta.z / 120.0 * 0.05;
                scene_camera.matrices_need_update = true;
            }
        }

        set_mousepick_camera_offset(*context.state.im_context, scene_view_rect.position);

        if set_if_different(*mouse_pos, screen_mouse_pos) {
            mouse_pos.current = screen_mouse_pos;
            mouse_ray := screen_point_to_ray(*scene_camera, screen_mouse_pos);
            //mouse_ray.direction *= -1; // TODO: why is this necessary???

            // TODO: instead of using XY_PLANE which is at zero, we should use
            // a plane at the Z of the 2D rectangle we're moving.
            intersected, enter := raycast(XY_PLANE, mouse_ray);
            if intersected
                world_mouse_pos = mouse_ray.origin + mouse_ray.direction * enter;

            clear(*hover);
            did_set_hover := false;
            for hovered_entity_handles() {
                if !did_set_hover {
                    did_set_hover = true;
                    set(*hover, it.handle);
                }
                break;
            }
        }

        {
            // Update cursor based on where it is in the object's UV.
            // i.e., arrow, or "ne corner resize," etc.
            cursor: ImGui.MouseCursor = .Arrow;
            for hovered_entity_handles() {
                cursor := get_cursor_for_drag_edge(get_drag_edge(it.handle, it.uv));
                ImGui.SetMouseCursor(cursor);
                screenp("cursor % for uv % with handle handle %", cursor, it.uv, it.handle);
                rect := entity_rect(it.handle);
                screenp("  entity_rect: %", rect);
                break;
            }
        }
        
        if ImGui.IsMouseReleased(0) {
            // If the mouse has released but not dragged, we do selection stuff.
            if distance_squared(v3(drag_state.origin), world_mouse_pos) < 0.1 {
                Undo.push_array(*undo_state, *selected);

                if !tentative_hover_click.has_value {
                    took_action := false;

                    editor_undo_push_selected();
                    if hover.has_value {
                        set_or_toggle_selected_in_hover_stack();
                    } else {
                        clear_selection();
                    }
                }
            }

            clear(*tentative_hover_click);
        }

        if ImGui.IsMouseClicked(0) {
            clear(*tentative_hover_click);
            for * selected {
                trs := get_transform_or_null(it.handle);
                if trs != null
                    Undo.push(*undo_state, trs);
            }

            drag_state.dragging = true;
            drag_state.origin = world_mouse_pos.xy;

            hovered := hovered_entity_handles();
            for hovered {
                drag_state.edge = get_drag_edge(it.handle, it.uv);
                // TODO: how to "join" cursor modes?
                // or should there be more than one state? one for each object?
            }
            //screenp("drag_state.edge %\n", drag_state.edge);

            // if selected is hovered now, it gets dragged
            // otherwise, if there's something hovered, it becomes selected and started dragging

            selected_is_hovered := false;
            for selected_obj: selected
                for hovered_handle: hovered
                    if hovered_handle.handle == selected_obj.handle
                        selected_is_hovered = true;

            if !selected_is_hovered {
                if hover.has_value {
                    Undo.push_array(*undo_state, *selected);
                    editor_undo_push_transform(hover.value);
                    set_selected(hover.value);
                    set(*tentative_hover_click, hover.value);
                } else {
                    clear_selection();
                }
            }

            for * selected {
                trs := get_transform_or_null(it.handle);
                if !trs continue;
                it.original_pos   = trs.position.xy;
                it.original_scale = trs.scale.xy;
            }
        }
    }

    if ImGui.IsMouseClicked(0) {
    } else if drag_state.dragging && !ImGui.IsMouseDown(0) {
        if selected.count == 0 {
            rect := rect_from_points(drag_state.origin, world_mouse_pos.xy);
            if is_valid_drag_rect(rect) {
                if callbacks.did_drag != null
                    callbacks.did_drag(rect);
            }
        } else
            Undo.commit(*undo_state);

        drag_state.dragging = false;

    } else if drag_state.dragging && ImGui.IsMouseDown(0) {
        delta := world_mouse_pos.xy - drag_state.origin;
        for selected {
            using it;
            trs := get_transform_or_null(it);
            if trs == null continue;
            if drag_state.edge == {
                case .None;      trs.position.xy = original_pos     + delta;
                case .East;
                    trs.scale.x     = original_scale.x + delta.x;

                case .South;     trs.scale.y     = original_scale.y + delta.y;
                case .SouthEast; trs.scale.xy    = original_scale   + delta;
                case .West;
                    trs.position.x = original_pos.x   + delta.x;
                    trs.scale.x    = original_scale.x - delta.x;

                    // TODO: this is the logic, the kind that needs to go to the other cases, for when the scale would go negative.
                    // but now i'm starting to wonder if there isn't a simpler data structure for this that unifies all the cases
                    // into a direction Vector like (1,-1) and a "two points" system where you're moving the points around. I think
                    // that is probably the way to go here...rect_from_corners probably already exists anyways.
                    if trs.scale.x < 0 {
                        trs.scale.x *= -1;
                        trs.position.x -= trs.scale.x;
                    }
                case .North;
                    trs.position.y = original_pos.y   + delta.y;
                    trs.scale.y    = original_scale.y - delta.y;
                case .NorthWest;
                    trs.position.xy = original_pos   + delta;
                    trs.scale.xy    = original_scale - delta;
                case .SouthWest;
                    trs.position.x  = original_pos.x   + delta.x;
                    trs.scale.x     = original_scale.x - delta.x;
                    trs.scale.y     = original_scale.y + delta.y;
                case .NorthEast;
                    trs.position.y  = original_pos.y   + delta.y;
                    trs.scale.y     = original_scale.y - delta.y;
                    trs.scale.x     = original_scale.x + delta.x;
            }
        }
    }

    if rl.IsKeyPressed(.KEY_DELETE) {
        if selected.count > 0 {
            editor_undo_push_selected();
            for selected {
                if hover.value == it.handle {
                    Undo.push(*undo_state, *hover);
                    hover.has_value = false;
                }
                destroy_entity(it, undo=*undo_state);
            }
            clear_selection();
        }
    }

    if !io.WantCaptureKeyboard {
        for i: 0..NUM_SAVE_SLOTS-1 {
            key_code := cast(rl.KeyboardKey)(cast(s32)rl.KeyboardKey.KEY_ONE + i);
            if rl.IsKeyPressed(key_code) {
                filename := scene_filename_for_slot(i + 1);
                if shift_down {
                    save_scene(filename=filename);
                } else {
                    load_scene_confirming(scene_filename=filename);
                }
            }
        }

        if rl.IsKeyPressed(.KEY_S) && ctrl_down {
            // Save the scene under the same name.
            save_scene();
        }
        if rl.IsKeyPressed(.KEY_I) && ctrl_down {
            Assets.reimport_all();
        }
    }

    if ctrl_down && rl.IsKeyPressed(.KEY_N) {
        // new scene
        new_scene_confirming();
    }

    U :: inline () -> *Undo.Impl  { return *context.state.editor.undo_state; }

    if ctrl_down && rl.IsKeyPressed(.KEY_D) {
        editor_undo_push_selected();
        new_handles := tmap(selected, s => duplicate_entity(s.handle, undo=U()));
        set_selected(new_handles);
    }

    if ctrl_down && rl.IsKeyPressed(.KEY_Z) {
        if !Undo.try_undo(U())
            log("nothing to undo");
    }
    if ctrl_down && rl.IsKeyPressed(.KEY_Y) {
        if !Undo.try_redo(U())
            log("nothing to redo");
    }
}

scene_filename_for_slot :: (slot_index: int) -> string {
    assert(slot_index >= 1 && slot_index <= 9);
    return scene_filename_for_short_name(tprint("%", slot_index));
}

scene_filename_for_short_name :: (short_name: string) -> string {
    filename := tprint("prefabs/scenes/%.wbml", short_name);
    return filename;
}

clear_selection :: () {
    using context.state.editor;
    if selected.count == 0 return;
    array_reset(*selected);
}

set_or_toggle_selected_in_hover_stack :: () {
    using context.state.editor;

    hovered := hovered_entity_handles();
    last_idx := -1;
    for hovered_obj, hovered_idx: hovered {
        for sel: selected {
            if sel.handle == hovered_obj.handle {
                last_idx = hovered_idx;
            }
        }
    }
    last_idx += 1;
    if last_idx >= hovered.count {
        last_idx = 0;
    }

    if last_idx >= 0 && last_idx < hovered.count {
        handle := hovered[last_idx].handle;
        editor_undo_push_transform(handle);
        set_selected(handle);
    }
}

editor_undo_push_selected :: () #expand {
    using context.state.editor;

    Undo.push_array(*undo_state, *selected);
    `defer Undo.commit(*undo_state);
}

editor_undo_push_transform :: (handle: Entity_Handle) {
    // call this when we're about to move an entity by changing the values of
    // its transform
    trs := get_transform_or_null(handle);
    if trs != null {
        Undo.push(*context.state.editor.undo_state, trs);
    } else {
        log_error("editor_undo_push_transform: no transform for handle: %", handle);
    }
}

set_or_toggle_selected :: (entity_handle:  Entity_Handle) {
    ctrl_down := rl.IsKeyDown(.KEY_LEFT_CONTROL) || rl.IsKeyDown(.KEY_RIGHT_CONTROL);
    if ctrl_down toggle_selection(entity_handle);
    else set_selected(entity_handle);
}

set_selected :: (entity_handles: [..]Entity_Handle, commit_undo := false) {
    using context.state.editor;

    array_reset(*selected);
    for entity_handles
        array_add(*selected).handle = it;

    if commit_undo
        Undo.commit(*undo_state);
}

set_selected :: (entity_handle: Entity_Handle, commit_undo := false) {
    using context.state.editor;

    if selected.count == 1 && selected[0].handle == entity_handle
        return;

    array_reset(*selected);
    selected_obj := array_add(*selected);
    selected_obj.handle = entity_handle;

    if commit_undo Undo.commit(*undo_state);
}

toggle_selection :: (entity_handle: Entity_Handle) -> bool {
    using context.state.editor;

    for selected if it.handle == entity_handle {
        remove it;
        return false;
    }

    selected_obj := array_add(*selected);
    selected_obj.handle = entity_handle;

    return true;
}

editor_toggle :: (using s: *State) {
    using editor;

    if play_mode == .Play || (play_mode == .Edit && fading_to_play) {
        fading_to_play = false;
        play_mode = .Edit;
    } else if play_mode == .Edit {
        fading_to_play = true;
    } else {
        log_error("unknown play_mode '%'", play_mode);
    }
}

load_scene :: (slot_index: int) {
    load_scene(scene_filename_for_slot(slot_index));
}

find_unused_scene_filename :: () -> string {
    // find an unused "Untitled" scene filename name

    counter := 0;
    scene_filename: string;

    while true {
        short_name := "Untitled";
        if counter > 0
            short_name = tprint("%-%", "Untitled", counter);

        scene_filename = scene_filename_for_short_name(short_name);

        print("checking if exists: %\n", scene_filename);

        if !platform.path_exists(scene_filename)
            break;

        counter += 1;
    }

    assert(scene_filename.count > 0);
    return scene_filename;
}

new_scene :: () {
    clear_selection();
    reset_world(context.state.world);
    free_and_clear_string(*context.state.editor.last_loaded_scene_filename);
}

new_scene_confirming :: () {
    using context.state.editor;

    if !undo_state.needs_save {
        new_scene();
        return;
    }

    assert(pending_scene_load.state == .None);
    pending_scene_load.state = .Waiting;
    assert(pending_scene_load.filename.count == 0);
    ImGui.OpenPopup(SAVE_CHANGES_MODAL_ID);
}

load_scene_confirming :: (scene_filename: string) {
    using context.state.editor;
    
    if !undo_state.needs_save {
        log("we didn't need to save; loading scene '%'", scene_filename);
        load_scene(scene_filename);
        return;
    }

    assert(pending_scene_load.state == .None);
    pending_scene_load.state = .Waiting;
    copy_into_owned_string(*pending_scene_load.filename, scene_filename);
    ImGui.OpenPopup(SAVE_CHANGES_MODAL_ID);
}


SAVE_CHANGES_MODAL_ID :: "Save Changes?";

get_center_of_main_viewport :: () -> ImGui.ImVec2 {
    using ImGui;

    //ImVec2              GetCenter() const       { return ImVec2(Pos.x + Size.x * 0.5f, Pos.y + Size.y * 0.5f); }
    viewport := GetMainViewport();
    center := make_ImVec2(viewport.Pos.x + viewport.Size.x * 0.5, viewport.Pos.y + viewport.Size.y * 0.5);
    //center := GetCenter(viewport); // this is an ImGui inline function not currently implemented in the bindings.
    return center;
}

center_next_window :: () {
    using ImGui;

    SetNextWindowPos(get_center_of_main_viewport(), .Appearing, make_ImVec2(0.5, 0.5));
}

save_changes_modal :: () {
    //
    // ask if the user would like to save scene changes, discard them, or cancel.
    //

    using context.state.editor;
    if pending_scene_load.state != .Waiting
        return;
        
    using ImGui;

    center_next_window();
    if BeginPopupModal(SAVE_CHANGES_MODAL_ID, null, .AlwaysAutoResize) {
        defer EndPopup();

        TextUnformatted(tprint("Do you want to save changes to the current scene?\n\n  %\n", last_loaded_scene_filename));
        Separator();

        if Button("Save", make_ImVec2(120, 0)) {
            save_scene();
            if pending_scene_load.filename.count > 0
                load_scene(pending_scene_load.filename);
            else
                new_scene();
            free_and_clear_string(*pending_scene_load.filename);
            pending_scene_load.state = .None;
            CloseCurrentPopup();
        }

        SameLine();
        if Button("Don't Save", make_ImVec2(120, 0)) {
            if pending_scene_load.filename.count > 0
                load_scene(pending_scene_load.filename);
            else
                new_scene();
            free_and_clear_string(*pending_scene_load.filename);
            pending_scene_load.state = .None;
            CloseCurrentPopup();
        }

        SetItemDefaultFocus();
        SameLine();
        if Button("Cancel", make_ImVec2(120, 0)) {
            free_and_clear_string(*pending_scene_load.filename);
            pending_scene_load.state = .None;
            CloseCurrentPopup();
        }
    }
}

#scope_file 

imtex :: (live_texture: *LiveTexture, empty_size := ImGui.ImVec2.{100, 100}) -> (*void, ImGui.ImVec2) {
    // A shortcut for getting the things you need to render an image in ImGui
    // from a LiveTexture (namely, a void pointer to the GL texture ID, and an
    // ImVec2 for the size).

    if live_texture == null || !has_value(<<live_texture)
        return null, empty_size;

    assert(live_texture.canary == LiveTexture.CANARY_TYPE_VALUE);
    texture := live_texture.resource;

    if texture.views.count == 0
        return null, empty_size;

    texture_ptr := texture.views[0];
    return cast(*void)texture_ptr, ImGui.make_ImVec2(cast(float)texture.width, cast(float)texture.height);
}

draw_inspector :: (open: *bool) {
    using context.state.editor;
    using ImGui;

    entity: *Entity;
    entity_handle: Entity_Handle;

    ok: bool;
    if selected.count == {
        case 0; 
            // do nothing
        case 1;
            entity_handle = selected[0].handle;
            ok, entity = get_entity(entity_handle);
    }

    defer End();

    pushed_alpha := false;
    if selected.count == 0 && !inspector_has_focus {
        PushStyleVar(.Alpha, 0.2);
        pushed_alpha = true;
    }
    if !Begin("Inspector", open)
        return;
    inspector_has_focus = IsWindowFocused();
    if pushed_alpha PopStyleVar();

    if selected.count > 1 {
        Text("Multiple objects are selected.");
        return;
    }

    classify_node :: (name: *u8, data: *void, ti: *Type_Info) -> bool {
        // Here we have the inspector omit showing info for the  "using component: Component;"
        // field (this is the field that makes a struct a subclass of Component).
        return cast(*Type_Info)type_info(Component) != ti;
    }

    if entity == null {
        PushPopStyleColor(.Text, .{.35, .35, .35, 1});
        Text("Nothing selected.");
        return;
    }

    Popup_Context :: struct {
        component_ptr: *Component;
        component_ti: *Type_Info_Struct;

        component_ptr_to_delete: *Component;
    }
    popup_ctx: Popup_Context;

    for entity.components {
        component_ti := component_bit_to_ti(it.bit);
        assert(component_ti != null);

        component_ptr := get_component(entity, component_ti);
        assert(component_ptr != null);
        PushPopFont(context.state.ui.small_font);

        popup_ctx.component_ptr = component_ptr;
        popup_ctx.component_ti = component_ti;;

        inspect("", component_ptr, component_ti, classify_node, categorize_type, custom_ctrl, xx popup_cb, *popup_ctx);
        popup_cb :: (popup_ctx_data: *Popup_Context) {
            using popup_ctx_data;
            if BeginPopupContextItem("component context menu") {
                defer EndPopup();
                if Selectable(tprint("Delete %\0", component_ti.name).data)
                    component_ptr_to_delete = cast(*Component)component_ptr;
            }
        }
    }

    if popup_ctx.component_ptr_to_delete {
        remove_component(popup_ctx.component_ptr_to_delete, undo=*undo_state);
    }

    {
        PushPopFont(context.state.ui.small_font);
        if Button("Add Component")
            OpenPopup("add_component_popup");
    }

    if BeginPopup("add_component_popup") {
        defer EndPopup();

        bits_ti := cast(*Type_Info_Enum)type_info(Component_Bit);
        for bits_ti.names {
            if MenuItem(it.data, shortcut="", false) {
                add_component(entity_handle, component_bit_to_ti(cast(Component_Bit)bits_ti.values[it_index]), undo=*undo_state);
                Undo.commit(*undo_state);
            }
        }
    }

    if entity != null {
        Text(tprint("Entity %\0", entity_handle.id).data);
    }
}

entity_selector :: (name: string, entity_handle: *Entity_Handle) -> bool {
    using context.state;
    using ImGui;

    assert(entity_handle != null);

    PushPopID(entity_handle);

    ok, entity := get_entity(<<entity_handle);
    
    label: string;
    button_res: bool;
    if !ok {
        button_res = Button("None");
    } else {
        button_res = Button(temp_c_string(entity.name));
    }
    if button_res {
        OpenPopup("entity_selector");
    }

    SameLine();
    TextUnformatted(tprint(" %", name));

    if BeginPopup("entity_selector") {
        defer EndPopup();

        filter := *editor.selector_filter;
        TextFilter.Draw(filter);

        if Selectable("[None]") {
            <<entity_handle = .{};
        }

        selected_handle: Maybe(Entity_Handle);
        for handles(*world.entities) {
            ok, entity := get_entity(it);
            assert(ok);
            PushID(entity);
            defer PopID();
            if TextFilter.PassFilter(filter, entity.name) {
                if (Selectable(entity.name.data)) {
                    selected_handle.has_value = true;
                    selected_handle.value = it;
                }
            }
        }

        if selected_handle.has_value {
            <<entity_handle = selected_handle.value;
            return true;
        }
    }

    return false;
}

focus_editor_camera_on_entity :: (entity_handle: Entity_Handle) {
    camera := get_main_camera();
    if camera == null {
        log_error("no camera to move");
        return;
    }

    ok, entity := get_entity(entity_handle);
    if !ok return;

    pos: Maybe(Vector2);
    r := entity_rect(entity);

    if r.width > 0 && r.height > 0 {
        pos.value = midpoint(r);
        pos.has_value = true;
    } else {
        trs := get_transform(entity);
        if trs != null {
            pos.value = trs.position.xy;
            pos.has_value = true;
        }
    }

    if pos.has_value {
        using context.state.editor;
        scene_camera.position.xy = pos.value;
        scene_camera.matrices_need_update = true;
    }
}

load_scene :: (filename: string) {
    wbml_str, ok := File.read_entire_file(filename);
    if !ok {
        log_error("could not read '%' - load failed", filename);
        return;
    }

    clear_selection();
    world := context.state.world;
    reset_world(world);
    load_world(world, wbml_str, filename);
    log("loaded scene '%'", filename);

    using context.state.editor;
    copy_into_owned_string(*last_loaded_scene_filename, filename);
    Undo.mark_needs_save(*undo_state, needs_save=false);
}

free_and_clear_string :: (str: *string) {
    assert(str != null);
    free(str.data);
    <<str = "";
}

copy_into_owned_string :: (str: *string, new_value: string) {
    assert(str != null);
    free(str.data);
    <<str = copy_string(new_value);
}

save_scene :: (filename: string) {
    using editor_state();
    save_prefab(filename);
    log("saved scene '%'", filename);
    Undo.mark_needs_save(*undo_state, false);
}

save_scene :: () {
    using editor_state();
    if last_loaded_scene_filename.count == 0 {
        // TODO: show a modal, or a file dialog
        new_filename := find_unused_scene_filename();
        save_prefab(new_filename);
        log("saved '%'", new_filename);
    } else {
        save_prefab(last_loaded_scene_filename);
        log("saved '%'", last_loaded_scene_filename);
        free_and_clear_string(*last_loaded_scene_filename);
    }
}

HelpMarker :: (desc: string) {
    using ImGui;

    TextDisabled("(?)");
    if IsItemHovered() {
        BeginTooltip();
        defer EndTooltip();

        PushTextWrapPos(ImGui.GetFontSize() * 35.0);
        defer PopTextWrapPos();

        TextUnformatted(desc);
    }
}

#scope_export
ImGui :: #import "imgui_docking";
#scope_file

want_mouselook :: () -> bool {
    return is_key_down(.MOUSE_BUTTON_RIGHT) || is_key_down(#char "C");
}

editor_state :: () -> *Editor { return *context.state.editor; }

ButtonEx :: (label: *u8, size:ImGui.ImVec2 = .{}, enabled := true) -> bool {
    using ImGui;
    if !enabled PushStyleVar(.Alpha, 0.5);
    defer if !enabled PopStyleVar();
    res := Button(label, size);
    return enabled && res;
}


#load "../lib/imgui_inspector.jai";
#load "../lib/imgui_macros.jai";

File           :: #import "File";
File_Utilities :: #import "File_Utilities";
String         :: #import "String";
#import "Math";
#import "Sloppy_Math";
#import "Input";
#import "Random";

screenlog      :: #import "screenlog";
wbml           :: #import "wbml";
inp            :: #import "inp";
rl             :: #import "raylib";
platform       :: #import "platform";
#import "math_extra";
#import "toolbelt";
#import "tween";
#import "Array_With_Holes";
#import "Live_Types";
#import "renderer_im_impl";
#import "renderer";
#import "camera";

Maybe :: struct(T: Type) {
    using value: T;
    has_value: bool;
}
set :: (using maybe: *Maybe, new_value: $T) {
    has_value = true;
    value = new_value;
}
clear :: (using maybe: *Maybe) {
    has_value = false;
}
eq :: (using maybe: *Maybe, value_to_compare: $T) -> bool {
    return has_value && value == value_to_compare;
}

is_key_pressed :: (key: Key_Code) -> bool { return (<<_local_host_state.input_button_states)[cast(int)key] & .START != 0; }
is_key_pressed :: (ch: u8) -> bool        { return is_key_pressed(cast,trunc(Key_Code)ch); }

is_key_down    :: (ch: u8) -> bool        { return is_key_down(cast,trunc(Key_Code)ch); }
is_key_down    :: (key: Key_Code) -> bool { return (<<_local_host_state.input_button_states)[cast(int)key] & .DOWN != 0; }

temp_c_string_obj :: (s: string) -> string {
    result : *u8 = talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    res: string;
    res.data = result;
    res.count = s.count;
    return res;
}

temp_c_string :: (s: string) -> *u8 {
    result : *u8 = talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
}

#scope_file
Assets :: #import "assets";
Grid :: #import "grid";
