is_name_a_System_Stage :: inline (name: string) -> bool    {
    #insert #run (() -> string {
        sb: String_Builder;
        defer free_buffers(*sb);

        print_to_builder(*sb, "return ");
        for type_info(System_Stage).names
            print_to_builder(*sb, "name == \"%\" || ", it);
        print_to_builder(*sb, "0;\n");
            

        return builder_to_string(*sb);
    }());
}

System_Stage :: enum {
    on_enable;
    update;
    late_update;
    pre_draw;
    draw;
    on_disable;

    // TODO: if you add to this enum, you also need to update the string
    // comparison in collect_component_functions. see the note there about solving this....
}

is_event_func :: (stage: System_Stage) -> bool {
    // returns true if the System_Stage is an "event func" like on_enable
    if stage == {
        case .on_enable; #through;
        case .on_disable;
            return true;
        case;
            return false;
    }
}

