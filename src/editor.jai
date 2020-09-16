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

#load "../lib/imgui_inspector.jai";

Play_Mode :: enum {
    Play;
    Edit;
}

Vec2 :: Vector2;

Selected_Object :: struct {
    using obj: *Entity;
    original_pos: Vector2;
}

Editor :: struct {
    play_mode: Play_Mode;

    drag_state: struct {
        dragging: bool;
        origin: Vec2;
    };

    selected: [..]Selected_Object;
    hover: *Entity;

    world_mouse_pos: Vector2;
    mouse_pos: Latch(Vector2);
}

editor_draw_world :: (state: *State) {
    using context.state.editor;

    if play_mode == .Play return;

    if selected.count > 0 {
        for selected {
            DrawRectangleLinesEx(entity_rect(it.obj), 2, WHITE);
        }
    } else if drag_state.dragging {
        DrawRectangleLinesEx(rect_from_points(drag_state.origin, world_mouse_pos), 3, RED);
    }

    if hover != null {
        DrawRectangleLinesEx(entity_rect(hover), 1, Color.{200, 200, 255, 128});
    }

}

demo_window_open: bool = true;

base_flags: ImGui.TreeNodeFlags = ImGui.TreeNodeFlags.OpenOnArrow | .OpenOnDoubleClick | .SpanAvailWidth;
align_label_with_current_x_position:bool = false;
test_drag_and_drop:bool = false;
selection_mask: s32 = (1 << 2);
entities_open := true;

draw_inspector :: (editor_state: *Editor) {
    using ImGui;

    Begin("Inspector");
    defer End();


    entity: *Entity;
    if editor_state.selected.count == {
        case 0; 
            Text("Select an entity to inspect it.");
            return;
        case 1;
            entity = editor_state.selected[0].obj;
        case;
            Text("TODO: implement multiple selection.");
            return;
    }

    inspect("Transform", *entity.transform);

    for entity.components {
        component_ti := get_component_ti_from_name(it.type_name);
        assert(component_ti != null);

        component_ptr := get_component(entity, component_ti);
        inspect(component_ti.name.data, component_ptr, component_ti);
    }
}

editor_draw :: (state: *State) {
    if state.editor.play_mode == .Play return;

    using context.state;

    color := YELLOW;
    color.a = cast(u8)(255 * (Math.sin(Time.now * 10) + 2) * 0.5);
    DrawText("editing", 275, 330, 16, color);


    // dockspace
    fullscreen :: true;
    padding    :: false;

    menubar :: false;

    window_flags := ImGui.WindowFlags.NoDocking;
    if menubar window_flags |= .MenuBar;

    if fullscreen {
        viewport := ImGui.GetMainViewport();
        ImGui.SetNextWindowPos(viewport.GetWorkPos(viewport));
        ImGui.SetNextWindowSize(viewport.GetWorkSize(viewport));
        ImGui.SetNextWindowViewport(viewport.ID_);
        ImGui.PushStyleVar(.WindowRounding, 0);
        ImGui.PushStyleVar(.WindowBorderSize, 0);
        window_flags |= ImGui.WindowFlags.NoTitleBar | .NoCollapse | .NoResize | .NoMove |
                        .NoBringToFrontOnFocus | .NoNavFocus;
    }
    window_flags |= .NoBackground;
    open := true;
    {
        if !padding ImGui.PushStyleVar(.WindowPadding, make_ImVec2(0, 0));
        ImGui.Begin("DockSpace Demo", *open, window_flags);
        defer ImGui.End();
        if !padding ImGui.PopStyleVar();

        if fullscreen
            ImGui.PopStyleVar(2);

        io := ImGui.GetIO();
        assert(io.ConfigFlags_ & .DockingEnable != 0);

        // dockspace
        dockspace_flags := ImGui.DockNodeFlags.PassthruCentralNode;
        ImGui.DockSpace(ImGui.GetID("Main DockSpace"), make_ImVec2(0, 0), dockspace_flags);

        if menubar {
            ImGui.BeginMenuBar();
            ImGui.EndMenuBar();
            if  ImGui.BeginMenu("Options") {
                defer ImGui.EndMenu();

            }
            HelpMarker("Some example help text goes here.");
        }
    }

    if demo_window_open
        ImGui.ShowDemoWindow(*demo_window_open);

    if ui_open {
        ImGui.Begin("state", *ui_open);
        defer ImGui.End();

        inspect("state", *state);
    }

    if entities_open {
        using ImGui;
        Begin("entities", *entities_open);
        defer End();
        //if TreeNodeEx("Entities", .DefaultOpen) {
            //defer TreePop();

            node_clicked: *Entity;
            for * it, it_index: context.state.world.entities {

                flags := TreeNodeFlags.SpanAvailWidth;
                // flags |= .OpenOnArrow;

                for * sel: state.editor.selected
                    if sel.obj == it
                        flags |= .Selected;

                if TreeNodeEx(it, flags, "%s", it.name.data) {
                    defer TreePop();
                    //for * it.components {
                        //ImGui.Text(tprintz(it.type_name).data);
                    //}
                }

                if IsItemClicked()
                    node_clicked = it;
            }

            if node_clicked != null {
                set_selected(node_clicked);
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

    if ImGui.GetIO().WantCaptureMouse // don't let imgui clicks come through to this one.
        return;

    if false
        for * state.world.entities {
            e_rect := entity_rect(it, true);
            screenlog.world(e_rect.position, "%", e_rect);
        }

    Time := *state.Time;
    if play_mode == .Play return;

    editor_cam_speed := 250.0;
    if IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT)
        editor_cam_speed *= 2;

    cam_movement := inp.movement(inp.Input_Type.KEYBOARD_WASD);
    cam_movement += Vector2_Scale(v2(1, -1), inp.movement(inp.Input_Type.GAMEPAD_RIGHT_STICK));
    if cam_movement.x != 0 || cam_movement.y != 0
        cam_movement = normalize(cam_movement);

    state.camera.target += Vector2_Scale(v2(1, -1), cam_movement) * editor_cam_speed * Time.delta_time;

    took_action := false;
    ctrl_down := IsKeyDown(.KEY_LEFT_CONTROL) || IsKeyDown(.KEY_RIGHT_CONTROL);
    shift_down := IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT);
    
    if set_if_different(*mouse_pos, GetMousePosition()) {
        world_mouse_pos = get_mouse_world_pos(state.camera, state.screen.texture);

        hover = null;
        for * state.world.entities {
            if overlaps(entity_rect(it, true), world_mouse_pos) {
                hover = it;
            }
        }
    }

    if IsMouseButtonPressed(.MOUSE_LEFT_BUTTON) {
        if hover != null {
            if ctrl_down toggle_selection(hover);
            else set_selected(hover);
            took_action = true;
        }

        if !took_action clear_selection();

        drag_state.dragging = true;
        drag_state.origin = get_mouse_world_pos(state.camera, state.screen.texture);

        if took_action
            for * selected
                it.original_pos = it.position.xy;

    } else if (drag_state.dragging && !IsMouseButtonDown(.MOUSE_LEFT_BUTTON)) && selected.count == 0 {
        drag_state.dragging = false;

        rect := rect_from_points(drag_state.origin, world_mouse_pos);
        if rect.width > 5 && rect.height > 5 {
            color := RED;
            color.b = cast(u8)random_get_within_range(100, 255);

            block := envitem(
                *state.world,
                rect.position.x,
                rect.position.y,
                rect.size.x,
                rect.size.y,
                .PLATFORM,
                color
            );
        }
    } else if drag_state.dragging && IsMouseButtonDown(.MOUSE_LEFT_BUTTON) {
        delta := world_mouse_pos - drag_state.origin;
        for selected
            it.obj.position.xy = it.original_pos + delta;
    }

    if IsKeyPressed(.KEY_DELETE) {
        for selected {
            if hover == it.obj
                hover = null;

            destroy_entity(it.obj);
        }
        clear_selection();
    }

    if IsKeyPressed(.KEY_ONE) {
        if shift_down save_scene("1");
        else {
            clear_selection();
            load_scene("1");
        }
    }
}

clear_selection :: () {
    using context.state.editor;
    array_reset(*selected);
}

set_selected :: (obj: *Entity) {
    using context.state.editor;

    array_reset(*selected);

    selected_obj := array_add(*selected);
    selected_obj.obj = obj;
}

toggle_selection :: (obj: *Entity) -> bool {
    using context.state.editor;

    for selected {
        if it.obj == obj {
            remove it;
            return false;
        }
    }

    selected_obj := array_add(*selected);
    selected_obj.obj = obj;

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
    }
}

editor_draw_ui :: () {
    using context.state.editor;
    if play_mode == .Play return;

    DrawText(tprint("% %", cast(int)world_mouse_pos.x, cast(int)world_mouse_pos.y), 0, 0, 0, BLUE);
}

#scope_file 

load_scene :: (name: string) {
    filename := tprint("%.wbml", name);

    str, ok := File.read_entire_file(filename);
    if !ok {
        logprint("error", "could not read '%' - load failed", filename);
        return;
    }

    wbml.deserialize(str, *context.state.scene);

    logprint("editor", "loaded %", filename);
}

save_scene :: (name: string) {
    filename := tprint("%.wbml", name);

    str := wbml.serialize(*context.state.scene);
    File.write_entire_file(filename, str);

    logprint("editor", "saved %", filename);
}

HelpMarker :: (desc: string) {
    ImGui.TextDisabled("(?)");
    if ImGui.IsItemHovered() {
        ImGui.BeginTooltip();
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0);
        ImGui.TextUnformatted(tprintz(desc).data);
        ImGui.PopTextWrapPos();
        ImGui.EndTooltip();
    }
}

#scope_file
Math :: #import "Math";
wbml :: #import "wbml";
inp :: #import "inp";
File :: #import "File";
#import "Random";
#import "Array_With_Holes";
