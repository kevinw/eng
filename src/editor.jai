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

editor_draw :: (state: *State) {
    if state.editor.play_mode == .Play return;

    using context.state;

    color := YELLOW;
    color.a = cast(u8)(255 * (Math.sin(Time.now * 10) + 2) * 0.5);
    DrawText("editing", 275, 330, 20, color);

    #if IMGUI_ENABLED {
        ImGui.Begin("state", *ui_open);
        ImGui.ShowDemoWindow(*demo_window_open);
        inspect("state", *state);
        ImGui.End();
    }
}

editor_update :: (state: *State) {
    using context.state.editor;

    if ImGui.GetIO().WantCaptureMouse // don't let imgui clicks come through to this one.
        return;

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

            print("TODO: delete entity\n");
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

#scope_file
Math :: #import "Math";
wbml :: #import "wbml";
inp :: #import "inp";
File :: #import "File";
#import "Random";
#import "Array_With_Holes";
