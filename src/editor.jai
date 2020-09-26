/*

prefabs and undo
- prefab is 
{
    prefab_link "prefab_unique_name"

    // and overridden properties...
    x 42
    y 99

}

making undoing a delete of an entity would mean exactly the same thing as
serializing an object as a prefab, and instantiating it.  perhaps ids in the
context of serialized wbml can just be saved as they are in memory. but then
when instantiating them, they may get "reassigned". or is it simpler than that?
if undoing the deleting of an entity is just writing bytes again...

what are the simplest possible operations? make an object. save out the type
info. (hash the type info? and save that? and then be able to reference it
forever?)


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

#load "../lib/imgui_inspector.jai";

Undo :: #import "undo";

Play_Mode :: enum {
    Play;
    Edit;
}

Vec2 :: Vector2;

Selected_Object :: struct {
    using handle: Entity_Handle;
    original_pos: Vector2;
}

Maybe :: struct(V: Type) {
    using value: V;
    has_value: bool;
}

categorize_type :: (ti: *Type_Info) -> Struct_Looks_Like {
    if ti == type_info(Color) {
        return .Color_Byte4;
    }

    return .None;
}

Editor :: struct {
    undo_state: Undo.Impl;

    wants_keyboard: bool;

    tweens: Tweens;

    windows: struct {
        undo := true;
        demo := true;
        entities := true;
        ecs_internals := false;
    };

    play_mode: Play_Mode = .Edit;

    callbacks: struct {
        did_drag: #type (rect: Rectangle);
    };

    drag_state: struct {
        dragging: bool;
        origin: Vec2;
    };

    selected: [..]Selected_Object;
    hover: Maybe(Entity_Handle);

    world_mouse_pos: Vector2;
    mouse_pos: Latch(Vector2);

    last_click_time: float64 = -99999;
}

editor_draw_world :: (state: *State) {
    using context.state.editor;

    if play_mode == .Play return;

    if selected.count > 0 {
        for selected {
            ok, entity := get_entity(it);
            if ok DrawRectangleLinesEx(entity_rect(entity), 2, WHITE);
        }
    } else if drag_state.dragging {
        DrawRectangleLinesEx(rect_from_points(drag_state.origin, world_mouse_pos), 3, RED);
    }

    if hover.has_value {
        ok, entity := get_entity(hover);
        if ok
            DrawRectangleLinesEx(entity_rect(entity), 1, Color.{200, 200, 255, 128});
    }

}

base_flags: ImGui.TreeNodeFlags = ImGui.TreeNodeFlags.OpenOnArrow | .OpenOnDoubleClick | .SpanAvailWidth;
align_label_with_current_x_position:bool = false;
test_drag_and_drop:bool = false;
selection_mask: s32 = (1 << 2);

editor_draw :: (state: *State) {
    if state.editor.play_mode == .Play return;

    using state;

    color := YELLOW;
    color.a = cast(u8)(255 * (Math.sin(Time.now * 10) + 2) * 0.5);
    DrawText("editing", 275, 330, 16, color);

    // dockspace
    fullscreen :: true;
    padding    :: false;

    menubar :: false;

    window_flags := ImGui.WindowFlags.NoDocking;
    if menubar window_flags |= .MenuBar;

    using ImGui;

    if fullscreen {
        viewport := GetMainViewport();
        SetNextWindowPos(viewport.GetWorkPos(viewport));
        SetNextWindowSize(viewport.GetWorkSize(viewport));
        SetNextWindowViewport(viewport.ID_);
        PushStyleVar(.WindowRounding, 0);
        PushStyleVar(.WindowBorderSize, 0);
        window_flags |= WindowFlags.NoTitleBar | .NoCollapse | .NoResize | .NoMove |
                        .NoBringToFrontOnFocus | .NoNavFocus;
    }
    window_flags |= .NoBackground;
    open := true;
    {
        if !padding PushStyleVar(.WindowPadding, make_ImVec2(0, 0));
        Begin("DockSpace Demo", *open, window_flags);
        defer End();
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

    if editor.windows.demo
        ShowDemoWindow(*editor.windows.demo);

    ButtonEx :: (label: *u8, size:ImVec2 = .{0,0}, enabled := true) -> bool {
        if !enabled PushStyleVar(.Alpha, 0.5);
        defer if !enabled PopStyleVar();
        res := Button(label, size);
        return enabled && res;
    }

    if editor.windows.ecs_internals {
        Begin("DEBUG", *editor.windows.ecs_internals);
        defer End();

        inspect("internals", *state.world.entities.items, categorize_type_func=categorize_type);
    }


    if editor.windows.undo {
        using context.state.editor;
        Begin("Undo", *editor.windows.undo);
        defer End();

        if ButtonEx("Undo", enabled=Undo.can_undo(*undo_state))
            Undo.undo(*undo_state);

        SameLine();

        if ButtonEx("Redo", enabled=Undo.can_redo(*undo_state))
            Undo.redo(*undo_state);

        SetNextItemOpen(true);
        inspect("", *state.editor.undo_state);
    }

    if editor.windows.entities {
        Begin("entities", *editor.windows.entities);
        defer End();

        if Button("New") {
            entity_ptr, entity_handle := create_entity(undo=*editor.undo_state);
            set_selected(entity_handle);
            Undo.commit(*editor.undo_state);
        }

        //Text("%d total", count_items(*world.entities));

        PushStyleVar(.ItemSpacing, ImVec2.{0, 0});
        defer PopStyleVar();

        ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());
        defer ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());

        //if TreeNodeEx("Entities", .DefaultOpen) {
            //defer TreePop();

            node_clicked: Maybe(Entity_Handle);
            for handles(*world.entities) {
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
                    //dnd := BeginDragDropSource();
                    //defer { if dnd EndDragDropSource(); }

                    //if dnd SetDragDropPayload("_ENTITY", *it, size_of(Entity_Handle));
                    if TreeNodeEx(entity, flags, "%s", entity.name.data) {
                        defer TreePop();
                    }
                }
                
                if IsItemClicked() {
                    node_clicked.value = it;
                    node_clicked.has_value = true;
                }
            }

            if node_clicked.has_value {
                set_or_toggle_selected(node_clicked.value);
                if IsMouseDoubleClicked(0)
                    focus_editor_camera_on_entity(node_clicked.value);
            }

        //}

        if false && ImGui.TreeNode("Advanced, with Selectable nodes") {
            HelpMarker("This is a more typical looking tree with selectable nodes.\nClick to select, CTRL+Click to toggle, click on arrows or double-click to open.");
            ImGui.CheckboxFlags("ImGuiTreeNodeFlags_OpenOnArrow",       cast(*u32)*base_flags, cast(u32)ImGui.TreeNodeFlags.OpenOnArrow);
            ImGui.CheckboxFlags("ImGuiTreeNodeFlags_OpenOnDoubleClick", cast(*u32)*base_flags, cast(u32)ImGui.TreeNodeFlags.OpenOnDoubleClick);
            ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanAvailWidth",    cast(*u32)*base_flags, cast(u32)ImGui.TreeNodeFlags.SpanAvailWidth); ImGui.SameLine(); HelpMarker("Extend hit area to all available width instead of allowing more items to be laid out after the node.");
            ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanFullWidth",     cast(*u32)*base_flags, cast(u32)ImGui.TreeNodeFlags.SpanFullWidth);
            ImGui.Checkbox("Align label with current X position", *align_label_with_current_x_position);
            ImGui.Checkbox("Test tree node as drag source", *test_drag_and_drop);
            ImGui.Text("Hello!");
            if (align_label_with_current_x_position)
                ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());

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
                    if (ImGui.IsItemClicked())
                        node_clicked = cast(s32)i;
                    if test_drag_and_drop && ImGui.BeginDragDropSource() {
                        ImGui.SetDragDropPayload("_TREENODE", null, 0);
                        ImGui.Text("This is a drag and drop source");
                        ImGui.EndDragDropSource();
                    }
                    if node_open {
                        ImGui.BulletText("Blah blah\nBlah Blah");
                        ImGui.TreePop();
                    }
                } else {
                    // Items 3..5 are Tree Leaves
                    // The only reason we use TreeNode at all is to allow selection of the leaf. Otherwise we can
                    // use BulletText() or advance the cursor by GetTreeNodeToLabelSpacing() and call Text().
                    node_flags |= ImGui.TreeNodeFlags.Leaf | .NoTreePushOnOpen; // ImGuiTreeNodeFlags_Bullet
                    ImGui.TreeNodeEx(cast(*void)cast(int)i, node_flags, "Selectable Leaf %d", i);
                    if ImGui.IsItemClicked()
                        node_clicked = cast(s32)i;
                    if test_drag_and_drop && ImGui.BeginDragDropSource() {
                        ImGui.SetDragDropPayload("_TREENODE", null, 0);
                        ImGui.Text("This is a drag and drop source");
                        ImGui.EndDragDropSource();
                    }
                }
            }
            if node_clicked != -1 {
                // Update selection state
                // (process outside of tree loop to avoid visual inconsistencies during the clicking frame)
                if ImGui.GetIO().KeyCtrl
                    selection_mask ^= cast(s32)(1 << node_clicked);          // CTRL+click to toggle
                else //if (!(selection_mask & (1 << node_clicked))) // Depending on selection behavior you want, may want to preserve selection when clicking on item that is part of the selection
                    selection_mask = cast(s32)(1 << node_clicked);           // Click to single-select
            }
            if (align_label_with_current_x_position)
                ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());
            ImGui.TreePop();
        }
    }

    draw_inspector(*state.editor);
}

editor_update :: (state: *State) {
    using context.state.editor;

    defer wants_keyboard = ImGui.GetIO().WantCaptureKeyboard;

    if play_mode == .Play return;

    ctrl_down := rl.IsKeyDown(.KEY_LEFT_CONTROL) || rl.IsKeyDown(.KEY_RIGHT_CONTROL);
    shift_down := rl.IsKeyDown(.KEY_LEFT_SHIFT) || rl.IsKeyDown(.KEY_RIGHT_SHIFT);

    // Move editor camera with WASD
    if !ctrl_down {
        editor_cam_speed := 250.0;
        if rl.IsKeyDown(.KEY_LEFT_SHIFT) || rl.IsKeyDown(.KEY_RIGHT_SHIFT)
            editor_cam_speed *= 2;

        cam_movement := inp.movement(inp.Input_Type.KEYBOARD_WASD);
        cam_movement += Vector2_Scale(v2(1, -1), inp.movement(inp.Input_Type.GAMEPAD_RIGHT_STICK));
        if cam_movement.x != 0 || cam_movement.y != 0
            cam_movement = normalize(cam_movement);

        state.camera.target += Vector2_Scale(v2(1, -1), cam_movement) * editor_cam_speed * state.Time.delta_time;
    }
    
    if !ImGui.GetIO().WantCaptureMouse { // don't let imgui clicks come through to this one.
        if set_if_different(*mouse_pos, rl.GetMousePosition()) {
            world_mouse_pos = get_mouse_world_pos(state.camera, state.screen.texture);

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

        if IsMouseButtonPressed(.MOUSE_LEFT_BUTTON) {
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
            drag_state.origin = get_mouse_world_pos(state.camera, state.screen.texture);

            if took_action {
                for * selected {
                    trs := get_transform_or_null(it.handle);
                    if trs
                        it.original_pos = trs.position.xy;
                }
            }
        } else if (drag_state.dragging && !IsMouseButtonDown(.MOUSE_LEFT_BUTTON)) {
            if selected.count == 0 {
                rect := rect_from_points(drag_state.origin, world_mouse_pos);
                if rect.width > 5 && rect.height > 5 {
                    if callbacks.did_drag != null
                        callbacks.did_drag(rect);
                }
            } else
                Undo.commit(*undo_state);

            drag_state.dragging = false;

        } else if drag_state.dragging && IsMouseButtonDown(.MOUSE_LEFT_BUTTON) {
            delta := world_mouse_pos - drag_state.origin;
            for selected {
                trs := get_transform_or_null(it);
                if trs != null
                    trs.position.xy = it.original_pos + delta;
            }
        }
    } // WantCaptureMouse

    if IsKeyPressed(.KEY_DELETE) {
        if selected.count > 0 {
            for selected {
                if hover == it.handle
                    hover.has_value = false;

                destroy_entity(it, undo=*undo_state);
            }

            Undo.commit(*undo_state);
        }
        clear_selection();
    }

    if IsKeyPressed(.KEY_ONE) {
        if shift_down {
            save_scene("1");
        } else {
            clear_selection();
            load_scene("1");
        }
    }

    if ctrl_down && IsKeyPressed(.KEY_N) {
        reset_world(*state.world);
    }

    if ctrl_down && IsKeyPressed(.KEY_D) {
        logprint("editor", "TODO: implement duplicate");
    }

    if ctrl_down && IsKeyPressed(.KEY_Z) && Undo.can_undo(*undo_state) {
        Undo.undo(*undo_state);
    }
    if ctrl_down && IsKeyPressed(.KEY_Y) && Undo.can_redo(*undo_state)
        Undo.redo(*undo_state);
}

clear_selection :: () {
    using context.state.editor;

    if selected.count == 0 return;

    array_reset(*selected);
}

set_or_toggle_selected :: (entity_handle:  Entity_Handle) {
    ctrl_down := IsKeyDown(.KEY_LEFT_CONTROL) || IsKeyDown(.KEY_RIGHT_CONTROL);
    if ctrl_down toggle_selection(entity_handle);
    else set_selected(entity_handle);
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
    if play_mode == {
        case .Play;
            play_mode = .Edit;
        case .Edit;
            play_mode = .Play;
        case;
            print("error: unknown play_mode '%'\n", play_mode);
            return;
    }
    print("entering mode %\n", play_mode);
}

editor_draw_ui :: () {
    using context.state.editor;
    if play_mode == .Play return;

    DrawText(tprint("% %", cast(int)world_mouse_pos.x, cast(int)world_mouse_pos.y), 0, 0, 0, BLUE);
}

#scope_file 

draw_inspector :: (editor_state: *Editor) {
    using editor_state;

    using ImGui;

    Begin("Inspector");
    defer End();


    entity: *Entity;
    entity_handle: Entity_Handle;
    if editor_state.selected.count == {
        case 0; 
            // do nothing
        case 1;
            ok: bool;
            entity_handle = editor_state.selected[0].handle;
            ok, entity = get_entity(entity_handle);
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
        PushStyleColor(.Text, .{.35, .35, .35, 1});
        defer PopStyleColor();
        Text("Nothing selected.");
        return;
    }

    for entity.components {
        component_ti := component_bit_to_ti(it.bit);
        assert(component_ti != null);

        component_ptr := get_component(entity, component_ti);
        assert(component_ptr != null);
        inspect("", component_ptr, component_ti, classify_node, categorize_type);
    }

    if Button("Add Component")
        OpenPopup("add_component_popup");
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


focus_editor_camera_on_entity :: (entity_handle: Entity_Handle) {
    ok, entity := get_entity(entity_handle);
    if ok {
        trs := get_transform(entity);
        if trs != null
            context.state.camera.target = trs.position.xy;
    }
}

load_scene :: (name: string) {
    filename := tprint("%.wbml", name);

    wbml_str, ok := File.read_entire_file(filename);
    if !ok {
        logprint("error", "could not read '%' - load failed", filename);
        return;
    }

    reset_world(*context.state.world);
    load_world(*context.state.world, wbml_str);
    //wbml.deserialize(str, *context.state.scene);

    logprint("editor", "loaded %", filename);
}

save_scene :: (name: string) {
    filename := tprint("%.wbml", name);
    save_prefab(filename);
    /*

    //str := wbml.serialize(*context.state.scene);
    //File.write_entire_file(filename, str);
    assert(false, "TODO");
    */

    logprint("editor", "saved %", filename);
}

HelpMarker :: (desc: string) {
    using ImGui;

    TextDisabled("(?)");
    if IsItemHovered() {
        BeginTooltip();
        defer EndTooltip();

        PushTextWrapPos(ImGui.GetFontSize() * 35.0);
        defer PopTextWrapPos();

        TextUnformatted(tprintz(desc).data);
    }
}

#scope_file
Math :: #import "Math";
wbml :: #import "wbml";
inp :: #import "inp";
File :: #import "File";
#import "Random";
#import "tween";
#import "Array_With_Holes";
