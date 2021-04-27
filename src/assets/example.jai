#import "Basic";
#import "Math";
Assets :: #import "assets";
#import "guid";

main :: () {
    {
        using context.print_style.default_format_struct;
        use_long_form_if_more_than_this_many_members = -1;
        draw_type_name = true;
        use_newlines_if_long_form = true;
    }

    /*
    check_meta_files(".\\assets\\");
    materials := auto_materials();

    for materials {
        print("material % ------------\n", it_index);
        print("%\n", it);
    }
    */

    Assets.init();
    sleep_milliseconds(50);
    Assets.reimport_all();
    Assets.tick();
    Assets.shutdown();
    sleep_milliseconds(1000);

    //print("guids:\n%\n%\n%\n", gen_guid(), gen_guid(), gen_guid());
}
