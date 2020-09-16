#import "Basic";
#import "toolbelt";
#import "entity";

HOTLOADING_ENABLED :: true;

#import "game_sound_soloud";
#load "editor.jai";
#import "live_raylib";
#import "Live_Types";
screenlog :: #import "screenlog";
#import "raylib";

#load "plugin_exports.jai";

#load "../lib/ui.jai";

#add_context state: *State;

State :: struct {
    ui: UI_State;
    editor: Editor;
    live: Live_Asset_Database;
    sound_state: Sound_State;
    world: World;
}

on_host_shutdown :: () {
    
}

update_and_draw :: () {
    {
        PushDrawing();
        ClearBackground(RED);
    }
}
