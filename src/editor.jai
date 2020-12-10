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

1. camera controls
2. pause the game as is, or reset it back? --
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

edit a prefab
place a prefab

idea: animate the changes from a prefab to the current instance to show the difference
use the animation to "go back" to the prefab when you zoom in on it
*/

Undo :: #import "undo";

Editor :: struct {
    undo_state: Undo.Impl;

    wants_keyboard: bool;

    tweens: Tweens;

    selector_filter: ImGui.TextFilter;
    asset_selector_filter: ImGui.TextFilter;

    play_mode: Play_Mode = .Edit;
    fading_to_play: bool;

    callbacks: struct {
        did_drag: #type (rect: rl.Rectangle);
    };

    drag_state: struct {
        dragging: bool;
        origin: Vector2;
    };

    selected: [..]Selected_Object;
    hover: Maybe(Entity_Handle);

    editing_entity_name: Maybe(Entity_Handle);
    editing_entity_grab_focus := false;

    world_mouse_pos: Vector2;
    mouse_pos: Latch(Vector2);

    last_click_time: float64 = -99999;

    assets: [..]Asset;
    selected_asset: *Asset = null;

    last_loaded_scene_filename: string; @owned

    windows: struct {
        undo_internals := false;
        demo := true;
        entities := true;
        ecs_internals := false;
        assets := true;
        prefab_cache := false;
        asset_selector: struct {
            visible := false;
            selected_asset_type: Asset.Type;
            selected_asset: union {
                tex: *LiveTexture;
                shader: *LiveShader;
            };
        };
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
        live_shader: LiveShader;
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
    else if ti == type_info(LiveShader)
        return .Has_Custom_Control;
    else if ti == type_info(Transform)
        return .Has_Custom_Control;
    return .None;
}

custom_ctrl :: (name: string, data: *void, ti_struct: *Type_Info_Struct) {
    if ti_struct == type_info(Entity_Handle)
        entity_selector(name, cast(*Entity_Handle)data);
    else if ti_struct == type_info(LiveTexture) 
        live_image_editor(cast(*LiveTexture)data);
    else if ti_struct == type_info(LiveShader)
        live_shader_editor(name, cast(*LiveShader)data);
    else if ti_struct == type_info(Transform) {

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
        DragFloat3("pos", cast([3]float)*xrs.position);
        DragFloat3("scl", cast([3]float)*xrs.scale);

        quat := cast(*Vector4)*xrs.rotation;
        euler := quaternion_to_euler(<<quat);
        if DragFloat3("rotation", cast([3]float)*euler.x) {
            <<quat = euler_to_quaternion(euler.x, euler.y, euler.z);
            logprint("=quat", "changed euler % to quat %", euler, <<quat);
        }

        DragFloat4("quat", cast([4]float)quat);
    }
}

live_shader_editor :: (name: string, live_shader_ptr: *LiveShader) {
    using ImGui;

    live_shader := <<live_shader_ptr;
    if !has_value(live_shader) {
        PushPopID("null shader");
        if Button("No Shader Selected")
            set_asset_selector_visible(live_shader_ptr);
    } else {
        if Button("TODO: shadername here") {
            set_asset_selector_visible(live_shader_ptr);
            SetWindowFocus(ASSET_SELECTOR_WINDOW_NAME);
        }
        SameLine();
        TextUnformatted(tprint("%\0", name));
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


editor_init :: (editor: *Editor) {
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


editor_draw_world :: (state: *State) {
    using context.state.editor;

    if play_mode == .Play return;

    if selected.count > 0 {
        for selected {
            ok, entity := get_entity(it);
            if ok rl.DrawRectangleLinesEx(entity_rect(entity), 2, rl.WHITE);
        }
    } else if drag_state.dragging {
        rl.DrawRectangleLinesEx(rect_from_points(drag_state.origin, world_mouse_pos), 3, rl.RED);
    }

    if hover.has_value {
        ok, entity := get_entity(hover, check_count = true);
        if ok
            rl.DrawRectangleLinesEx(entity_rect(entity), 1, rl.Color.{200, 200, 255, 128});
    }

}

base_flags: ImGui.TreeNodeFlags = ImGui.TreeNodeFlags.OpenOnArrow | .OpenOnDoubleClick | .SpanAvailWidth;
align_label_with_current_x_position:bool = false;
test_drag_and_drop:bool = false;
selection_mask: s32 = (1 << 2);

editor_draw :: (state: *State) {
    if state.editor.play_mode == .Play return;
    render_imgui_to_drawlists(state);
}

set_asset_selector_visible :: (live_texture_ptr: *LiveTexture) {
    using context.state.editor.windows.asset_selector;
    visible = true;
    selected_asset_type = .Texture;
    selected_asset.tex = live_texture_ptr;
}

set_asset_selector_visible :: (live_shader_ptr: *LiveShader) {
    using context.state.editor.windows.asset_selector;
    visible = true;
    selected_asset_type = .Shader;
    selected_asset.shader = live_shader_ptr;
}

ASSET_SELECTOR_WINDOW_NAME :: "Assets##Selector";

render_asset_selector :: (window_open: *bool) {
    using ImGui;

    using context.state.editor.windows.asset_selector;

    BeginEnd(ASSET_SELECTOR_WINDOW_NAME, window_open);

    filter := *context.state.editor.asset_selector_filter;
    TextFilter.Draw(filter, "##asset selector filter text");

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

            if it.type != selected_asset_type || !TextFilter.PassFilter(filter, filename_z)
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
            tex_id, size := imtex(entry_tex, make_ImVec2(MAX_HEIGHT, MAX_HEIGHT));
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
                Text(filename_z);
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
                    <<selected_asset.shader = LiveShader.Empty;
                } else {
                    <<selected_asset.shader = LoadLiveShader("", it.filename);
                }
            }
        }
    }

    // TODO: the stuff below relies on methods that the new ImGui wrapper hasn't correctly bound yet.
    // specifically functions whose ABI is weird because of the return value optimization in C++.
    // once we can call GetWindowPos() without crashing this will work.

    //window_pos := ImGui.GetWindowPos();
    //print("window pos %\n", window_pos);
    //window_visible_x2 := window_pos.x;

    /*
    style := GetStyle();
    buttons_count := 20;
    window_visible_x2: float = GetWindowPos().x + GetWindowContentRegionMax().x;
    button_sz :: ImVec2.{40, 40};
    for n: 0..buttons_count - 1 {
        PushID(cast(*void)n);
        defer PopID();

        Button("Box", button_sz);
        last_button_x2 := GetItemRectMax().x;
        next_button_x2 := last_button_x2 + style.ItemSpacing.x + button_sz.x; // Expected position if next button was on same line
        if n + 1 < buttons_count && next_button_x2 < window_visible_x2
            SameLine();
    }
    */
}

edit_entity_name :: (handle: Entity_Handle) {
    using context.state.editor;

    editing_entity_name.has_value = true;
    editing_entity_name.value = handle;
    editing_entity_grab_focus = true;
}

render_imgui_to_drawlists :: (state: *State) {
    using state;

    // dockspace
    fullscreen :: true;
    padding    :: false;

    menubar :: false;


    using ImGui;


    {
        // fade the editor in and out when toggling between edit and play mode.
        using state.editor;
        if play_mode == .Edit {
            style := GetStyle();
            ALPHA_CHANGE_SPEED :: 9.0;
            if fading_to_play {
                style.Alpha -= Time.unscaled_delta_time * ALPHA_CHANGE_SPEED;
                if style.Alpha <= 0 {
                    fading_to_play = false;
                    style.Alpha = 0;
                    play_mode = .Play;
                }
            } else {
                if style.Alpha < 1 {
                    style.Alpha = clamp(style.Alpha + Time.unscaled_delta_time * ALPHA_CHANGE_SPEED, 0, 1);
                }
            }
        }
    }

    {
        window_flags := ImGui.WindowFlags.NoDocking;
        if menubar window_flags |= .MenuBar;

        if fullscreen {
            viewport := GetMainViewport();
            SetNextWindowPos(viewport.GetWorkPos(viewport));
            SetNextWindowSize(viewport.GetWorkSize(viewport));
            SetNextWindowViewport(viewport.ID_);
            PushStyleVar(.WindowRounding, 0);
            PushStyleVar(.WindowBorderSize, 0);
            window_flags |= ImGui.WindowFlags.NoTitleBar | .NoCollapse | .NoResize | .NoMove |
                            .NoBringToFrontOnFocus | .NoNavFocus;
        }
        window_flags |= .NoBackground;
        open := true;
        {
            if !padding PushStyleVar(.WindowPadding, make_ImVec2(0, 0));

            BeginEnd("DockSpace Demo", *open, window_flags);
            if !padding PopStyleVar();

            if fullscreen PopStyleVar(2);

            assert(GetIO().ConfigFlags_ & .DockingEnable != 0);

            // dockspace
            dockspace_flags := DockNodeFlags.PassthruCentralNode;
            DockSpace(ImGui.GetID("Main DockSpace"), make_ImVec2(0, 0), dockspace_flags);

            if menubar {
                BeginMenuBar();
                EndMenuBar();
                if  BeginMenu("Options") {
                    defer EndMenu();

                }
                HelpMarker("Some example help text goes here.");
            }
        }
    }

    if editor.windows.asset_selector.visible
        render_asset_selector(*editor.windows.asset_selector.visible);

    //if editor.windows.demo
        //ShowDemoWindow(*editor.windows.demo);

    ButtonEx :: (label: *u8, size:ImVec2 = .{0,0}, enabled := true) -> bool {
        if !enabled PushStyleVar(.Alpha, 0.5);
        defer if !enabled PopStyleVar();
        res := Button(label, size);
        return enabled && res;
    }

    if editor.windows.ecs_internals {
        BeginEnd("DEBUG", *editor.windows.ecs_internals);
        inspect("internals", *state.world.entities.items, categorize_type_func=categorize_type, custom_ctrl=custom_ctrl);
    }


    // Overlay showing compiler error
    has_compile_error, err_str := get_plugin_compile_error();
    if has_compile_error {
        {
            DISTANCE:float = 80.0;
            viewport         := GetMainViewport();
            work_area_pos    := viewport.GetWorkPos(viewport);   // Instead of using viewport->Pos we use GetWorkPos() to avoid menu bars, if any!
            work_area_size   := viewport.GetWorkSize(viewport);
            window_pos       := make_ImVec2(work_area_pos.x + DISTANCE, work_area_pos.y + DISTANCE);
            window_pos_pivot := make_ImVec2(0, 0);
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

    if editor.windows.undo_internals {
        using context.state.editor;
        BeginEnd("Undo", *editor.windows.undo_internals);
        if ButtonEx("Undo", enabled=Undo.can_undo(*undo_state))
            Undo.undo(*undo_state);

        SameLine();

        if ButtonEx("Redo", enabled=Undo.can_redo(*undo_state))
            Undo.redo(*undo_state);

        SetNextItemOpen(true);
        inspect("", *state.editor.undo_state);
    }

    if editor.windows.prefab_cache {
        BeginEnd("prefab cache", *editor.windows.prefab_cache);
        inspect("", *context.state.world.prefab_cache);
    }

    if editor.windows.assets {
        BeginEnd("assets", *editor.windows.assets);

        for * editor.assets {
            assert(it != null);
            PushPopID(it);

            //dnd := BeginDragDropSource();
            //defer { if dnd EndDragDropSource(); }
            //if dnd SetDragDropPayload("_ASSET", it, size_of(Asset));

            selected := editor.selected_asset == it;
            if Selectable(tprint("%\0", it.short_name).data, selected)
                editor.selected_asset = it;

            do_spawn := selected && IsItemHovered() && IsMouseDoubleClicked(0);
            do_edit_as_scene := false;

            if BeginPopupContextItem("asset context menu") {
                editor.selected_asset = it;
                defer EndPopup();
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

    if editor.windows.entities {
        BeginEnd("Entities", *editor.windows.entities);

        PushFont(context.state.ui.small_font);
        if Button("New") {
            PopFont();
            entity_ptr, entity_handle := create_entity(undo=*editor.undo_state);
            set_selected(entity_handle);
            Undo.commit(*editor.undo_state);
        } else
            PopFont();

        //Text("%d total", count_items(*world.entities));

        PushStyleVar(.ItemSpacing, ImVec2.{0, 0});
        defer PopStyleVar();


        //if TreeNodeEx("Entities", .DefaultOpen) {
            //defer TreePop();

            node_clicked: Maybe(Entity_Handle);
            for handles(*world.entities) {
                parent := get_parent(it);
                if parent != .{}
                    continue;

                flags := TreeNodeFlags.SpanAvailWidth;
                // flags |= .OpenOnArrow;
                flags |= .Leaf;

                ///
                /// MUST REMOVE .Leaf once we have parent entities!
                //

                for * sel: state.editor.selected
                    if sel.handle == it
                        flags |= .Selected;

                ok, entity := get_entity(it);
                if ok {
                    PushPopID(entity);

                    using state.editor;
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

                        name_label := tprint("% - %\0", entity.name, child_count(it));
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
                }
                
                if IsItemClicked() {
                    node_clicked.value = it;
                    node_clicked.has_value = true;
                }
            }

            if node_clicked.has_value {
                using state.editor;
                was_selected := selected.count == 1 && selected[0].handle == node_clicked.value;
                set_or_toggle_selected(node_clicked.value);
                if IsMouseDoubleClicked(0)
                    focus_editor_camera_on_entity(node_clicked.value);
                else if IsMouseClicked(0) && was_selected {
                    edit_entity_name(node_clicked.value);
                }
            }

        //}

        if false && ImGui.TreeNode("Advanced, with Selectable nodes") {
            defer TreePop();
            HelpMarker("This is a more typical looking tree with selectable nodes.\nClick to select, CTRL+Click to toggle, click on arrows or double-click to open.");
            CheckboxFlags("ImGuiTreeNodeFlags_OpenOnArrow",       cast(*u32)*base_flags, cast(u32)TreeNodeFlags.OpenOnArrow);
            CheckboxFlags("ImGuiTreeNodeFlags_OpenOnDoubleClick", cast(*u32)*base_flags, cast(u32)TreeNodeFlags.OpenOnDoubleClick);
            CheckboxFlags("ImGuiTreeNodeFlags_SpanAvailWidth",    cast(*u32)*base_flags, cast(u32)TreeNodeFlags.SpanAvailWidth); ImGui.SameLine(); HelpMarker("Extend hit area to all available width instead of allowing more items to be laid out after the node.");
            CheckboxFlags("ImGuiTreeNodeFlags_SpanFullWidth",     cast(*u32)*base_flags, cast(u32)TreeNodeFlags.SpanFullWidth);
            Checkbox("Align label with current X position", *align_label_with_current_x_position);
            Checkbox("Test tree node as drag source", *test_drag_and_drop);
            Text("Hello!");
            if (align_label_with_current_x_position)
                Unindent(ImGui.GetTreeNodeToLabelSpacing());

            // 'selection_mask' is dumb representation of what may be user-side selection state.
            //  You may retain selection state inside or outside your objects in whatever format you see fit.
            // 'node_clicked' is temporary storage of what node we have clicked to process selection at the end
            /// of the loop. May be a pointer to your own node type, etc.
            node_clicked:s32 = -1;
            for i: 0..5 {
                // Disable the default "open on single-click behavior" + set Selected flag according to our selection.
                node_flags := base_flags;
                is_selected := (selection_mask & (1 << i)) != 0;
                if is_selected
                    node_flags |= .Selected;
                if i < 3 {
                    // Items 0..2 are Tree Node
                    node_open:bool = ImGui.TreeNodeEx(cast(*void)cast(int)i, node_flags, "Selectable Node %d", i);
                    if IsItemClicked()
                        node_clicked = cast(s32)i;
                    if test_drag_and_drop && ImGui.BeginDragDropSource() {
                        defer ImGui.EndDragDropSource();
                        SetDragDropPayload("_TREENODE", null, 0);
                        Text("This is a drag and drop source");
                    }
                    if node_open {
                        BulletText("Blah blah\nBlah Blah");
                        TreePop();
                    }
                } else {
                    // Items 3..5 are Tree Leaves
                    // The only reason we use TreeNode at all is to allow selection of the leaf. Otherwise we can
                    // use BulletText() or advance the cursor by GetTreeNodeToLabelSpacing() and call Text().
                    node_flags |= TreeNodeFlags.Leaf | .NoTreePushOnOpen; // ImGuiTreeNodeFlags_Bullet
                    TreeNodeEx(cast(*void)cast(int)i, node_flags, "Selectable Leaf %d", i);
                    if ImGui.IsItemClicked()
                        node_clicked = cast(s32)i;
                    if test_drag_and_drop && ImGui.BeginDragDropSource() {
                        SetDragDropPayload("_TREENODE", null, 0);
                        Text("This is a drag and drop source");
                        EndDragDropSource();
                    }
                }
            }
            if node_clicked != -1 {
                // Update selection state
                // (process outside of tree loop to avoid visual inconsistencies during the clicking frame)
                if GetIO().KeyCtrl
                    selection_mask ^= cast(s32)(1 << node_clicked);          // CTRL+click to toggle
                else //if (!(selection_mask & (1 << node_clicked))) // Depending on selection behavior you want, may want to preserve selection when clicking on item that is part of the selection
                    selection_mask = cast(s32)(1 << node_clicked);           // Click to single-select
            }
            if (align_label_with_current_x_position)
                Indent(ImGui.GetTreeNodeToLabelSpacing());

            // Pressing F2 will edit the selected entity's name.
            using context.state.editor;
            if rl.IsKeyPressed(.KEY_F2)
                logprint("editor", "F2 was pressed!");
            if !editing_entity_name.has_value && rl.IsKeyPressed(.KEY_F2) && selected.count == 1 {
                edit_entity_name(selected[0].handle);
            }
        }
    }

    draw_inspector(*state.editor);

    if 0 {
        BeginEnd("Debug Internals");
        io := ImGui.GetIO();
        TextUnformatted(tprint("IniFilename: s", io.IniFilename));
    }
}

editor_update :: (state: *State) {
    using context.state.editor;

    io := ImGui.GetIO();

    defer wants_keyboard = io.WantCaptureKeyboard;

    if play_mode == .Play return;

    ctrl_down := rl.IsKeyDown(.KEY_LEFT_CONTROL) || rl.IsKeyDown(.KEY_RIGHT_CONTROL);
    shift_down := rl.IsKeyDown(.KEY_LEFT_SHIFT) || rl.IsKeyDown(.KEY_RIGHT_SHIFT);

    if !io.WantTextInput {
        if rl.IsKeyPressed(.KEY_P) {
            if context.state.global_time_scale > 0
                context.state.global_time_scale = 0;
            else
                context.state.global_time_scale = 1;
        }
    }

    camera := get_main_camera_2D();

    // Move editor camera with WASD
    if !ctrl_down && camera && !io.WantTextInput {
        editor_cam_speed := 250.0;
        if rl.IsKeyDown(.KEY_LEFT_SHIFT) || rl.IsKeyDown(.KEY_RIGHT_SHIFT)
            editor_cam_speed *= 2;

        cam_movement := inp.movement(inp.Input_Type.KEYBOARD_WASD);
        cam_movement += Vector2_Scale(v2(1, -1), inp.movement(inp.Input_Type.GAMEPAD_RIGHT_STICK));
        if cam_movement.x != 0 || cam_movement.y != 0
            cam_movement = normalize(cam_movement);

        camera.target += Vector2_Scale(v2(1, -1), cam_movement) * editor_cam_speed * state.Time.unscaled_delta_time;
    }
    
    if !io.WantCaptureMouse { // don't let imgui clicks come through to this one.
        if set_if_different(*mouse_pos, rl.GetMousePosition()) {

            world_mouse_pos = get_mouse_world_pos(camera, state.screen.texture);

            hover.has_value = false;
            for handles(*state.world.entities) {
                ok, entity := get_entity(it);
                assert(ok);
                e_rect := entity_rect(entity, true);
                if overlaps(e_rect, world_mouse_pos) {
                    hover.value = it;
                    hover.has_value = true;
                }
            }
        }

        if rl.IsMouseButtonPressed(.MOUSE_LEFT_BUTTON) {
            Undo.push_array(*undo_state, *selected);

            took_action := false;
            if hover.has_value {
                set_or_toggle_selected(hover.value);
                took_action = true;
            }

            if !took_action
                clear_selection();

            for * selected {
                trs := get_transform_or_null(it.handle);
                if trs != null
                    Undo.push(*undo_state, trs);
            }

            drag_state.dragging = true;
            drag_state.origin = get_mouse_world_pos(camera, state.screen.texture);

            if took_action {
                for * selected {
                    trs := get_transform_or_null(it.handle);
                    if trs
                        it.original_pos = trs.position.xy;
                }
            }
        } else if (drag_state.dragging && !rl.IsMouseButtonDown(.MOUSE_LEFT_BUTTON)) {
            if selected.count == 0 {
                rect := rect_from_points(drag_state.origin, world_mouse_pos);
                if rect.width > 5 && rect.height > 5 {
                    if callbacks.did_drag != null
                        callbacks.did_drag(rect);
                }
            } else
                Undo.commit(*undo_state);

            drag_state.dragging = false;

        } else if drag_state.dragging && rl.IsMouseButtonDown(.MOUSE_LEFT_BUTTON) {
            delta := world_mouse_pos - drag_state.origin;
            for selected {
                trs := get_transform_or_null(it);
                if trs != null
                    trs.position.xy = it.original_pos + delta;
            }
        }

        wheel := rl.GetMouseWheelMove();
        if camera != null && wheel != 0 {
            camera.zoom = clamp(camera.zoom + cast(float)wheel * 0.05, 0.25, 3.0);
            logprint("=camera zoom", "camera zoom %", camera.zoom);
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
            name := tprint("%", (i + 1));
            key_code := cast(rl.KeyboardKey)(cast(s32)rl.KeyboardKey.KEY_ONE + i);
            if rl.IsKeyPressed(key_code) {
                filename := tprint("prefabs/scenes/%.wbml", name);
                if shift_down {
                    save_scene(filename=name);
                } else {
                    clear_selection();
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

clear_selection :: () {
    using context.state.editor;

    if selected.count == 0 return;

    array_reset(*selected);
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

#scope_file 

imtex :: (live_texture: *LiveTexture, empty_size := ImGui.ImVec2.{100, 100}) -> (*void, ImGui.ImVec2) {
    // A shortcut for getting the things you need to render an image in ImGui
    // from a LiveTexture (namely, a void pointer to the GL texture ID, and an
    // ImVec2 for the size).

    if !has_value(<<live_texture) return null, empty_size;

    size := make_ImVec2(cast(float)live_texture.resource.width, cast(float)live_texture.resource.height);
    return cast(*void)*live_texture.resource, size;
}


draw_inspector :: (editor_state: *Editor) {
    using editor_state;

    using ImGui;

    BeginEnd("Inspector");
    entity: *Entity;
    entity_handle: Entity_Handle;
    if editor_state.selected.count == {
        case 0; 
            // do nothing
        case 1;
            ok: bool;
            entity_handle = editor_state.selected[0].handle;
            ok, entity = get_entity(entity_handle);
            if ok Text(tprint("Entity %\0", entity_handle.id).data);
        case;
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
        logprint("error", "could not read '%' - load failed", filename);
        return;
    }
    reset_world(*context.state.world);
    load_world(*context.state.world, wbml_str, filename);
    logprint("editor", "loaded scene '%'", filename);

    using context.state.editor;
    set_owned_string(*last_loaded_scene_filename, filename);

    cam := find_component(Cam);
    if !cam {
        entity, entity_handle := create_entity(*context.state.world, "Editor Camera", undo=*context.state.editor.undo_state);
        entity.flags |= Entity.Flags.Hide_In_Inspector | .Dont_Save;

        cam = add_component(entity_handle, Cam);
    }
}

set_owned_string :: (str: *string, new_value: string) {
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
make_ImVec2 :: ImGui.make_ImVec2;
#scope_file

#load "../lib/imgui_inspector.jai";
#load "../lib/imgui_macros.jai";


File_Utilities :: #import "File_Utilities";
#import "toolbelt";
#import "Math";
wbml :: #import "wbml";
inp :: #import "inp";
File :: #import "File";
rl :: #import "raylib";
String :: #import "String";
#import "Random";
#import "tween";
#import "Array_With_Holes";
#import "Live_Types";
Maybe :: struct(T: Type) {
    using value: T;
    has_value: bool;
}
