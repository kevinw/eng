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

input :: #import "input";

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
}

editor_draw_world :: (state: *State) {
    using state.editor;

    if play_mode == .Play return;
    DrawText("EDITOR", 300, 300, 25, YELLOW);

    if drag_state.dragging {
        p1 := drag_state.origin;
        p2 := get_mouse_world_pos(state.camera);
        print("% %\n", p1, p2);
        DrawRectangleLinesEx(rect_from_points(p1, p2), 3, RED);
    }
}

editor_update :: (state: *State, delta_time: float) {
    using state.editor;
    if play_mode == .Play return;

    EDITOR_CAM_SPEED :: 4.0;
    state.camera.target += input.movement(.KEYBOARD_WASD) * EDITOR_CAM_SPEED * delta_time;

    if IsMouseButtonPressed(.MOUSE_LEFT_BUTTON) {
        drag_state.dragging = true;
        drag_state.origin = get_mouse_world_pos(state.camera);
    } else if (drag_state.dragging && !IsMouseButtonDown(.MOUSE_LEFT_BUTTON)) {
        drag_state.dragging = false;

        p1 := drag_state.origin;
        p2 := get_mouse_world_pos(state.camera);
        rect := rect_from_points(p1, p2);
    }
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

    print("play_mode %\n", play_mode);
}
