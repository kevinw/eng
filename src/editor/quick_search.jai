// TODO: use metaprogramming @annotations on functions to populate this list
quick_search_tasks := Quick_Search_Entry.[
    .{"Show ImGui Demo Window", show_imgui_demo_window},
    .{"Quit", request_application_quit}
];

show_quick_search_window :: (open: *bool) {
    using ImGui;
    using context.state.editor;

    BeginEnd_return("Quick Search", open);

    enter_pressed := false;

    TextFilter.Draw(*quick_search_filter);
    if quick_search.just_opened {
        quick_search.just_opened = false;
        quick_search.selected_index = 0;
        quick_search.selected_index_delta = 0;
        SetKeyboardFocusHere(-1);
    } else {
        if IsItemDeactivated() && IsKeyPressed(GetKeyIndex(.Escape)) {
            log("escape pressed!");
            <<open = false;
        } else if IsKeyPressed(GetKeyIndex(.Enter)) {
            enter_pressed = true;
        }
        
        quick_search.selected_index_delta = 0;
        if IsKeyPressed(GetKeyIndex(.DownArrow))
            quick_search.selected_index_delta += 1;
        if IsKeyPressed(GetKeyIndex(.UpArrow))
            quick_search.selected_index_delta -= 1;
    }

    // See if we need to find a new index (like if the search changed and the
    // selected item isn't visible anymore.)
    needs_update := true;
    for quick_search_tasks {
        if TextFilter.PassFilter(*quick_search_filter, it.label) {
            if it_index == quick_search.selected_index {
                needs_update = false;
                break;
            }
        }
    }

    // If the selected index needs to change because of an arrow key, or
    // because the list of visible elements changed, find the "closest" index
    // and use that.
    MAX_VAL :: 999999;
    min_delta := MAX_VAL;
    if quick_search.selected_index_delta != 0 || needs_update {
        new_index := quick_search.selected_index + quick_search.selected_index_delta;
        for quick_search_tasks {
            if TextFilter.PassFilter(*quick_search_filter, it.label) {
                diff := abs(it_index - new_index);
                if diff < min_delta {
                    quick_search.selected_index = it_index;
                    min_delta = diff;
                }
            }
        }
        if min_delta == MAX_VAL // ...or if we found nothing, use zero.
            quick_search.selected_index = 0;
    }


    // Draw the quick search items and invoke a callback if necessary.
    for quick_search_tasks if TextFilter.PassFilter(*quick_search_filter, it.label) {
        needs_to_run := false;
        if Selectable(it.label.data, it_index == quick_search.selected_index)
            needs_to_run = true;
        if enter_pressed && it_index == quick_search.selected_index
            needs_to_run = true;
        if needs_to_run {
            it.func();
            <<open = false;
        }
    }

    /*
    // this is the old "search/filter through all the editor Type_Infos" thing
    inspect_opts := editor_inspect_opts();
    inspect_opts.filter = *quick_search_filter;
    inspect("", *context.state.editor, opts=inspect_opts);
    */
}

Quick_Search_Entry :: struct {
    label: string;
    func: #type ();
}
