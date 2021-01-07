/*

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

     - we're going to need an "entity" class.
     - the player needs to be a prefab (does it?)
    
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
        origin: Vector2;
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

    windows: struct {
        inspector      := true;
        demo           := true;
        entities       := true;
        assets         := true;
        screenlog      := true;
        undo_internals := false;
        prefab_cache   := false;
        ecs_internals  := false;
        asset_selector: struct {
            filter: ImGui.TextFilter;
            visible := false;
            selected_asset_type: Asset.Type;
            selected_asset: union {
                tex: *LiveTexture;
                shader: *Shader;
            };
        };
        gamepad_viz := false;
        profiler    := true;
    };
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
}

InputTextStr :: (str: *string) -> bool {
    MAX_SIZE :: 200;
    assert(str.count < MAX_SIZE);

    buf := cast(*u8)talloc(MAX_SIZE + 1);
    memcpy(buf, str.data, str.count);
    buf[str.count] = #char "\0";

    res:bool = ImGui.InputText("", buf, MAX_SIZE);
    if res {
        new_len := str_length(buf);
        
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
    if ti == type_info(Entity_Handle)
        entity_selector(name, cast(*Entity_Handle)data);
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

        using ImGui;

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
            logprint("=quat", "changed euler % to quat %", euler, <<quat);
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
}

is_valid_drag_rect :: (rectangle: rl.Rectangle) -> bool {
    return rectangle.width > 5 || rectangle.height > 5;
}

editor_draw_world :: (state: *State) {
    using context.state.editor;

    if play_mode == .Play return;

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
    using ImGui;

    defer End();
    if !Begin(ASSET_SELECTOR_WINDOW_NAME, window_open) return;

    using context.state.editor.windows.asset_selector;

    TextFilter.Draw(*filter, "##asset selector filter text");

    assets: [..]*Asset;
    assets.allocator = __temporary_allocator;
    array_add(*assets, null);
    for * context.state.editor.assets
        array_add(*assets, it);
        
    for assets {
        filename_z:string = "None";
        if it != null {
            sans_ext := String.path_strip_extension(it.short_name);
            filename_z = tprint("%\0", sans_ext);

            if it.type != selected_asset_type || !TextFilter.PassFilter(*filter, filename_z)
                continue;

            // TODO: this is requesting we load the image. we should probably
            // have a background task, or a "pending image loads" queue or
            // something...
            if it.type == .Texture && !has_value(it.live_texture)
                it.live_texture = LoadLiveTexture(it.filename);
        }

        if selected_asset_type == {
        case .Texture;
            live_tex := selected_asset.tex;
            selected_tex_id, selected_tex_size := imtex(live_tex);
            entry_tex := ifx it == null then *LiveTexture.Empty else *it.live_texture;
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
            if Button(tprint("%\0", label).data) {
                if it == null {
                    selected_asset.shader = null;
                } else {
                    logprint("editor", "TODO: change shader");
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
            work_area_pos    := viewport.GetWorkPos(viewport);   // Instead of using viewport->Pos we use GetWorkPos() to avoid menu bars, if any!
            work_area_size   := viewport.GetWorkSize(viewport);
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
                Text(tprint("%\0", err_str).data);
            }
        }
    }

    if state.editor.play_mode == .Play
        return;

    PushPopStyleVar(.Alpha, editor.fading_alpha); // from here on out, we may be fading out the entire editor. when going to play mode

    {
        window_flags :: ImGui.WindowFlags.NoDocking | .NoTitleBar | .NoCollapse
            | .NoResize | .NoMove | .NoBringToFrontOnFocus | .NoNavFocus |
            .NoBackground;

        viewport := GetMainViewport();
        SetNextWindowPos(viewport.GetWorkPos(viewport));
        SetNextWindowSize(viewport.GetWorkSize(viewport));
        SetNextWindowViewport(viewport.ID_);
        PushStyleVar(.WindowRounding, 0);
        PushStyleVar(.WindowBorderSize, 0);
        {
            PushStyleVar(.WindowPadding, ImGui.make_ImVec2(0, 0));
            defer End();
            open := true;
            Begin("DockSpace Demo", *open, window_flags);
            PopStyleVar();
            PopStyleVar(2);
            assert(GetIO().ConfigFlags_ & .DockingEnable != 0);
            DockSpace(GetID("Main DockSpace"), .{}, DockNodeFlags.PassthruCentralNode);
            if is_key_down(.MOUSE_BUTTON_RIGHT) // TODO: only change the cursor when the mouse is over the "scene"
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
    if windows.demo ImGui.ShowDemoWindow(*editor.windows.demo);
    if windows.undo_internals show_undo_internals(*windows.undo_internals);
    if windows.assets show_assets_window(*windows.assets);
    if windows.entities show_entities_window(*windows.entities);
    if windows.inspector draw_inspector(*windows.inspector);
    if windows.asset_selector.visible render_asset_selector(*windows.asset_selector.visible);
    if windows.gamepad_viz show_gamepad_window(*windows.gamepad_viz);
    if windows.profiler show_profiler_window(*windows.profiler);
    //inspect("", *context.state.multiview);
    //inspect("", *context.state.editor);
}

show_profiler_window :: (open: *bool) {
    using context.state;
    using ImGui;
    
    defer End();
    if !Begin("Profiler", open) return;

    if profiler_text.count > 0
        TextUnformatted(profiler_text);
    else
        TextUnformatted("No data.");
}

show_gamepad_window :: (open: *bool) {
    using context.state;
    using ImGui;

    defer End();
    if !Begin("Gamepad", open) return;

    Gamepad :: #import "Gamepad";

    inspect("", *Gamepad.gamepad);
}

show_assets_window :: (open: *bool) {
    using context.state;
    using ImGui;

    defer End();
    if !Begin("assets", open) return;

    for * editor.assets {
        assert(it != null);
        PushPopID(it);

        //dnd := BeginDragDropSource();
        //defer { if dnd EndDragDropSource(); }
        //if dnd SetDragDropPayload("_ASSET", it, size_of(Asset));

        selected := editor.selected_asset == it;
        if Selectable(tprint("%\0", String.path_strip_extension(it.short_name)).data, selected)
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
            pos: Vector3;
            camera := get_main_camera();
            if camera != null { pos = get_worldspace_center(camera); }

            entity_handle: Entity_Handle;
            entity: *Entity;
            offset: Vector2;

            if it.type == {
                case .Prefab;
                    entity, entity_handle = spawn_prefab_from_filename(it.filename, pos, undo=*editor.undo_state);
                    offset = entity_rect(entity).size * 0.5;

                case .Texture;
                    entity, entity_handle = create_entity(*context.state.world, it.short_name, undo=*editor.undo_state, world_pos=pos);
                    img := add_component(entity_handle, Simple_Image_Renderer);
                    img.texture = LoadLiveTexture(it.filename);
                    offset = 0.5 * v2(img.texture.width, img.texture.height);

                case .Sprite;
                    entity, entity_handle := create_entity(*context.state.world, it.short_name, undo=*editor.undo_state, world_pos=pos);
                    spr := add_component(entity_handle, SpriteRenderer);
                    spr.sprite_anim = LoadLiveSprite(it.filename);
                    offset = 0.5 * entity_rect(entity_handle).size;

                case;
                    logprint("editor", "WARNING: unhandled asset type %", it.type);
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
            load_scene(it.filename);
        }
    }
}

show_undo_internals :: (open: *bool) {
    using context.state.editor;
    using ImGui;

    defer End();
    if !Begin("Undo", open) return;

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

    defer End();
    if !Begin("Entities", open)
        return;

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
                name_label := tprint("%\0", entity.name);
                if TreeNodeEx(entity, flags, name_label.data) {
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
                        logprint("editor", "make child: %\n", it);
                    }
                }
            }

            if IsItemClicked()
                set(*node_clicked, it);
        }
            

        using editor;
        if node_clicked.has_value {
            was_selected := selected.count == 1 && selected[0].handle == node_clicked.value;
            set_or_toggle_selected(node_clicked.value);
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

            if IsMouseClicked(0) && IsWindowHovered()
                clear_selection();
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

    pos: ImVec2 = .{250, 20};
    draw_list := GetForegroundDrawList();
    for logger_state.entries {
        if it.message.data == null || it.message.count == 0
            continue;
        
        alpha_factor: float = 1.0;
        FADE_TIME :: 0.1;
        if it.time < FADE_TIME alpha_factor = max(cast(float)0.0, cast(float)it.time) / FADE_TIME;

        alpha := cast(float)(it.time / 0.5);
        color: u32;
        if it.mode == .MINIMAL
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

hovered_entity_handles :: () -> []Entity_Handle {
    // returns valid entity handles underneath the mouse
    handles: [..]Entity_Handle;
    handles.allocator = __temporary_allocator;

    handle: Entity_Handle;
    for get_hovered_entities(*context.state.im_context) {
        handle.id = it.entity_id;
        handle.generation = it.entity_generation;
        ok, entity := get_entity(handle, check_count = true);
        if ok array_add(*handles, handle);
    }

    return handles;
}

editor_update :: (state: *State) {
    using context.state.editor;

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
            logprint("editor", "TODO: implement multiview toggling again");
            // context.state.multiview.enabled = !context.state.multiview.enabled;
        }
    }

    // Move editor camera with WASD

    if !io.WantTextInput && is_key_down(.MOUSE_BUTTON_RIGHT) {
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
            mouse_rotate_speed :: 0.17;
            if _local_host_state.mouse_delta_x != 0 || _local_host_state.mouse_delta_y != 0 {
                rotate_delta := mouse_rotate_speed * make_vector3(
                    // TODO: why are these backwards?
                    -cast(float)_local_host_state.mouse_delta_y,
                     cast(float)_local_host_state.mouse_delta_x,
                    0);

                TO_RADIANS :: 3.141592 / 180.0;
                x: Quaternion; set_from_axis_and_angle(*x, Vector3.{1, 0, 0}, rotate_delta.x * TO_RADIANS);
                y: Quaternion; set_from_axis_and_angle(*y, Vector3.{0, 1, 0}, rotate_delta.y * TO_RADIANS);
                z: Quaternion; set_from_axis_and_angle(*z, Vector3.{0, 0, 1}, rotate_delta.z * TO_RADIANS);

                temp := x * y * z * scene_camera.rotation;
                normalize_or_identity(*temp);
                scene_camera.rotation = temp;
                update = true;
            }
        }

        if update {
            scene_camera.matrices_need_update = true;
        }
    }


    if !io.WantCaptureMouse { // don't let imgui clicks come through to this one.
        mouse_x, mouse_y := platform.get_client_mouse_pos(_local_host_state.window_handle);
        screen_mouse_pos := v2(mouse_x, mouse_y);
        if set_if_different(*mouse_pos, screen_mouse_pos) {
            mouse_ray := screen_point_to_ray(*scene_camera, screen_mouse_pos);
            mouse_ray.direction *= -1; // TODO: why is this necessary???

            // TODO: instead of using XY_PLANE which is at zero, we should use
            // a plane at the Z of the 2D rectangle we're moving.
            intersected, enter := raycast(XY_PLANE, mouse_ray);
            if intersected
                world_mouse_pos = mouse_ray.origin + mouse_ray.direction * enter;

            clear(*hover);
            for hovered_entity_handles() {
                set(*hover, it);
                break;
            }
        }
        
        if ImGui.IsMouseReleased(0) {
            // If the mouse has released but not dragged, we do selection stuff.
            if distance_squared(v3(drag_state.origin), world_mouse_pos) < 0.1 {
                Undo.push_array(*undo_state, *selected);

                if !tentative_hover_click.has_value {
                    took_action := false;
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

            //if selected is hovered now, it gets dragged
            //otherwise, if there's something hovered, it becomes selected and started dragging

            selected_is_hovered := false;
            for selected_obj: selected
                for hovered_handle: hovered
                    if hovered_handle == selected_obj.handle
                        selected_is_hovered = true;

            if !selected_is_hovered {
                if hover.has_value {
                    set_selected(hover.value);
                    set(*tentative_hover_click, hover.value);
                } else {
                    clear_selection();
                }
            }

            for * selected {
                trs := get_transform_or_null(it.handle);
                if trs it.original_pos = trs.position.xy;
            }

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
                trs := get_transform_or_null(it);
                if trs != null
                    trs.position.xy = it.original_pos + delta;
            }
        }
    } // WantCaptureMouse

    if rl.IsKeyPressed(.KEY_DELETE) {
        if selected.count > 0 {
            Undo.push_array(*undo_state, *selected);

            for selected {
                if hover.value == it.handle {
                    Undo.push(*undo_state, *hover);
                    hover.has_value = false;
                }

                destroy_entity(it, undo=*undo_state);
            }

            clear_selection();
            Undo.commit(*undo_state);
        }
    }

    if !io.WantCaptureKeyboard {
        for i: 0..7 {
            key_code := cast(rl.KeyboardKey)(cast(s32)rl.KeyboardKey.KEY_ONE + i);
            if rl.IsKeyPressed(key_code) {
                filename := scene_filename_for_slot(i + 1);
                if shift_down {
                    save_scene(filename=filename);
                } else {
                    load_scene(filename=filename);
                }
            }
        }

        if rl.IsKeyPressed(.KEY_S) && ctrl_down {
            // Save the scene under the same name.
            save_scene();
        }
    }

    if ctrl_down && rl.IsKeyPressed(.KEY_N) {
        // new scene
        reset_world(*state.world);
    }

    if ctrl_down && rl.IsKeyPressed(.KEY_D) {
        new_handles: [..]Entity_Handle;
        new_handles.allocator = __temporary_allocator;

        Undo.push_array(*undo_state, *selected);
        for selected
            array_add(*new_handles, duplicate_entity(it.handle, undo=*undo_state));
        set_selected(new_handles);
        Undo.commit(*undo_state);
    }

    if ctrl_down && rl.IsKeyPressed(.KEY_Z) && Undo.can_undo(*undo_state) {
        Undo.undo(*undo_state);
    }
    if ctrl_down && rl.IsKeyPressed(.KEY_Y) && Undo.can_redo(*undo_state)
        Undo.redo(*undo_state);
}

scene_filename_for_slot :: (slot_index: int) -> string {
    assert(slot_index >= 1 && slot_index <= 9);
    filename := tprint("prefabs/scenes/%.wbml", slot_index);
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
    for hovered_handle, hovered_idx: hovered {
        for sel: selected {
            if sel.handle == hovered_handle {
                last_idx = hovered_idx;
            }
        }
    }
    last_idx += 1;
    if last_idx >= hovered.count {
        last_idx = 0;
    }

    if last_idx >= 0 && last_idx < hovered.count {
        set_selected(hovered[last_idx]);
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

    for selected {
        if it.handle == entity_handle {
            remove it;
            return false;
        }
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
        logprint("editor", "error: unknown play_mode '%'", play_mode);
    }
}

load_scene :: (slot_index: int) {
    load_scene(scene_filename_for_slot(slot_index));
}

#scope_file 

imtex :: (live_texture: *LiveTexture, empty_size := ImGui.ImVec2.{100, 100}) -> (*void, ImGui.ImVec2) {
    // A shortcut for getting the things you need to render an image in ImGui
    // from a LiveTexture (namely, a void pointer to the GL texture ID, and an
    // ImVec2 for the size).

    if !has_value(<<live_texture) return null, empty_size;

    size := ImGui.make_ImVec2(cast(float)live_texture.resource.width, cast(float)live_texture.resource.height);
    return cast(*void)*live_texture.resource, size;
}


draw_inspector :: (open: *bool) {
    using context.state.editor;
    using ImGui;

    defer End();
    if !Begin("Inspector", open)
        return;

    entity: *Entity;
    entity_handle: Entity_Handle;
    if selected.count > 1 {
        Text("Multiple objects are selected.");
        return;
    }

    ok: bool;
    if selected.count == {
        case 0; 
            // do nothing
        case 1;
            entity_handle = selected[0].handle;
            ok, entity = get_entity(entity_handle);
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

    component_ptr_to_delete: *Component;
    for entity.components {
        component_ti := component_bit_to_ti(it.bit);
        assert(component_ti != null);

        component_ptr := get_component(entity, component_ti);
        assert(component_ptr != null);
        PushPopFont(context.state.ui.small_font);
        inspect("", component_ptr, component_ti, classify_node, categorize_type, custom_ctrl);
        PushPopID(cast(*void)it_index);
        if BeginPopupContextItem("component context menu") {
            defer EndPopup();
            if Selectable(tprint("Delete %\0", component_ti.name).data) {
                component_ptr_to_delete = component_ptr;
            }
        }
    }

    if component_ptr_to_delete
        remove_component(component_ptr_to_delete);

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
    if !ok label = "None";
    else label = tprint("%\0", entity.name);

    if Button(label.data) {
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
        logprint("=editor_focus", "no camera to move");
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

    if pos.has_value
        set_worldspace_center(camera, pos.value);
}

load_scene :: (filename: string) {
    wbml_str, ok := File.read_entire_file(filename);
    if !ok {
        logprint("error", .MINIMAL, "could not read '%' - load failed", filename);
        return;
    }

    clear_selection();
    reset_world(*context.state.world);
    load_world(*context.state.world, wbml_str, filename);
    logprint("editor", "loaded scene '%'", filename);

    using context.state.editor;
    copy_into_owned_string(*last_loaded_scene_filename, filename);

    cam := find_component(Cam);
    if !cam {
        entity, entity_handle := create_entity(*context.state.world, "Editor Camera", undo=*context.state.editor.undo_state);
        entity.flags |= Entity.Flags.Hide_In_Inspector | .Dont_Save;

        cam = add_component(entity_handle, Cam);
    }
}

copy_into_owned_string :: (str: *string, new_value: string) {
    assert(str != null);
    free(str.data);
    <<str = copy_string(new_value);
}

save_scene :: (filename: string) {
    save_prefab(filename);
    logprint("editor", "saved scene '%'", filename);
}

save_scene :: () {
    using context.state.editor;

    if last_loaded_scene_filename.count == 0 {
        logprint("editor", "error: no last loaded scene filename");
        return;
    }

    save_prefab(last_loaded_scene_filename);
    logprint("editor", "saved '%'", last_loaded_scene_filename);
}

HelpMarker :: (desc: string) {
    using ImGui;

    TextDisabled("(?)");
    if IsItemHovered() {
        BeginTooltip();
        defer EndTooltip();

        PushTextWrapPos(ImGui.GetFontSize() * 35.0);
        defer PopTextWrapPos();

        TextUnformatted(tprint("%\0", desc));
    }
}

#scope_export
ImGui :: #import "imgui";
#scope_file

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
is_key_down    :: (ch: u8) -> bool { return is_key_down(cast,trunc(Key_Code)ch); }
is_key_down    :: (key: Key_Code) -> bool {
    res := (<<_local_host_state.input_button_states)[cast(int)key] & .DOWN != 0;
    //logprint("=ed", "is_key_down %: % (%)", key, res, _local_host_state.input_button_states); 
    return res;
}
