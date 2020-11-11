elapsed_time: float64;
last_time: float64;
dt: float;
TICK_PERIOD : float64 : 1.0/60.0; // time between game updates

main :: () {
    print("in main...\n");
    window_width  :: 800;
    window_height :: 450;
    title :: "Forge Host";

    the_window := create_window(window_width, window_height, title);

    /*
    using tf;

    if !MemAllocInit(APP_NAME)
        exit(1);

    fsDesc: FileSystemInitDesc;
    fsDesc.pAppName = APP_NAME;
	if !initFileSystem(*fsDesc)
		return;

    pSystemFileIO := get_pSystemFileIO();
	fsSetPathForResourceDir(pSystemFileIO, .DEBUG, .LOG, "");

    fsSetPathForResourceDir(pSystemFileIO, .CONTENT, .SHADER_SOURCES, "Shaders");
    fsSetPathForResourceDir(pSystemFileIO, .DEBUG,   .SHADER_BINARIES, "CompiledShaders");
    fsSetPathForResourceDir(pSystemFileIO, .CONTENT, .GPU_CONFIG, "GPUCfg");
    fsSetPathForResourceDir(pSystemFileIO, .CONTENT, .TEXTURES, "Textures");
    fsSetPathForResourceDir(pSystemFileIO, .CONTENT, .FONTS, "Fonts");

	Log.Init(APP_NAME);
    defer Log.Exit();

    settings: RendererDesc;
    renderer: *Renderer;
    initRenderer(APP_NAME, *settings, *renderer);
    if !renderer
        return;

    graphics_queue: Queue;

    queueDesc: QueueDesc;
    queueDesc.type = .GRAPHICS;
    queueDesc.flag = .INIT_MICROPROFILE;
    addQueue(renderer, *queueDesc, *graphics_queue);
    */
    

    quit := false;
    while !quit {
        update_window_events();
        for events_this_frame {
            if it.type == {
                case .QUIT;
                    quit = true;
            }
        }

        start_frame(the_window);
        finish_frame(the_window);
    }

    print("exit OK.\n");
}

start_frame :: (the_window: *Window_Type) {
    while true {
        if elapsed_time >= TICK_PERIOD {
            elapsed_time -= TICK_PERIOD;
            break;
        }

        now := get_time();
        if last_time dt = cast(float) (now - last_time);
        last_time = now;
        
        elapsed_time += dt;
        sleep_milliseconds(2);
    }

    reset_temporary_storage();
}

finish_frame :: (the_window: *Window_Type) {
    swap_buffers(the_window);
}

APP_NAME :: "Transforms";

#scope_file
tf :: #import "The_Forge";
#import "Window_Creation";
#import "Input";
#import "Basic";
