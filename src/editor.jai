Play_Mode :: enum {
    Play;
    Edit;
}

Editor :: struct {
    play_mode: Play_Mode;
}

editor_draw :: (using s: type_of(state)) {
    if editor.play_mode == .Play return;

}

editor_update :: (using s: type_of(state)) {
    if editor.play_mode == .Play return;

}