#scope_file

#import "Thread";
#import "Basic";

Windows :: #import "Windows"; // for Sleep

Asset_Pipeline :: struct {

}

asset_thread_proc :: (thread: *Thread) -> s64 {
    print("in asset thread!\n");
    count := 0;
    while true {
        Windows.Sleep(1000);
        //print("asset tick %\n", count);
        count += 1;
        tick_single_threaded();
    }
    return 0;
}

#scope_module

asset_thread: *Thread;

tick_single_threaded :: () {
    // TODO: debug the asset pipeline with a cooperative-multitasking
    // mode that runs every tick on the main thread.
}

start_thread :: () {
    asset_thread = New(Thread);
    thread_init(asset_thread, asset_thread_proc);
    thread_start(asset_thread);
}

stop_thread :: () {

}
