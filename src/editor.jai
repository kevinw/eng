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
*/

#scope_file

wbml :: #import "wbml";
input :: #import "input";
File :: #import "File";
#import "Random";

#scope_module

Play_Mode :: enum {
    Play;
    Edit;
}

Vec2 :: Vector2;

Editor :: struct {
    play_mode: Play_Mode;

    drag_state: struct {
        dragging: bool;
        origin: Vec2;
    };

    selected: [..]*Object;
}

editor_draw_world :: (state: *State) {
    using state.editor;

    if play_mode == .Play return;

    if drag_state.dragging {
        p1 := drag_state.origin;
        p2 := get_mouse_world_pos(state.camera, state.screen.texture);
        DrawRectangleLinesEx(rect_from_points(p1, p2), 3, RED);
    }

    if selected.count > 0 {
        for selected {
            DrawRectangleLinesEx(it.rect, 2, WHITE);
        }
    }
}

editor_draw :: (state: *State) {
    if state.editor.play_mode == .Play return;

    color := YELLOW;
    color.a = cast(u8)(255 * (Math.sin(Time.now * 10) + 2) * 0.5);
    DrawText("editing", 275, 330, 20, color);
}

editor_update :: (state: *State) {
    using state.editor;
    if play_mode == .Play return;

    editor_cam_speed := 200.0;
    if IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT)
        editor_cam_speed *= 2;

    state.camera.target += Vector2_Scale(v2(1, -1), input.movement(.KEYBOARD_WASD)) * editor_cam_speed * Time.delta_time;

    if IsMouseButtonPressed(.MOUSE_LEFT_BUTTON) {
        drag_state.dragging = true;
        drag_state.origin = get_mouse_world_pos(state.camera, state.screen.texture);
    } else if (drag_state.dragging && !IsMouseButtonDown(.MOUSE_LEFT_BUTTON)) {
        drag_state.dragging = false;

        p1 := drag_state.origin;
        p2 := get_mouse_world_pos(state.camera, state.screen.texture);
        rect := rect_from_points(p1, p2);

        block := array_add(*state.scene.envItems);
        block.rect = rect;
        block.collision = .PLATFORM;
        block.color = RED;
        block.color.b = cast(u8)random_get_within_range(100, 255);
        print("placed block #%\n", state.scene.envItems.count);
    }

    took_action := false;

    ctrl_down := IsKeyDown(.KEY_LEFT_CONTROL) || IsKeyDown(.KEY_RIGHT_CONTROL);
    shift_down := IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT);

    if IsMouseButtonPressed(.MOUSE_RIGHT_BUTTON) {
        world_mouse_pos := get_mouse_world_pos(state.camera, state.screen.texture);
        for * state.scene.envItems {
            if overlaps(it.rect, world_mouse_pos) {
                if ctrl_down
                    toggle_selection(it);
                else
                    set_selected(it);
                
                took_action = true;
            }
        }

        if !took_action clear_selection();
    }

    if IsKeyPressed(.KEY_DELETE) {
        for selected {
            for * scene_obj: state.scene.envItems
                if it == scene_obj
                    remove scene_obj;
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
    using state.editor;
    array_reset(*selected);
}

set_selected :: (obj: *Object) {
    using state.editor;

    array_reset(*selected);
    array_add(*selected, obj);
}

toggle_selection :: (obj: *Object) -> bool {
    using state.editor;

    for selected {
        if it == obj {
            remove it;
            return false;
        }
    }

    array_add(*selected, obj);
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

#scope_file 

load_scene :: (name: string) {
    filename := tprint("%.wbml", name);

    str, ok := File.read_entire_file(filename);
    if !ok {
        logprint("error", "could not read '%' - load failed", filename);
        return;
    }

    wbml.deserialize(str, *state.scene);

    logprint("editor", "loaded %", filename);
}

save_scene :: (name: string) {
    filename := tprint("%.wbml", name);

    str := wbml.serialize(*state.scene);
    File.write_entire_file(filename, str);

    logprint("editor", "saved %", filename);
}
