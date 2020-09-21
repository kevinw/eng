System_Stage :: enum {
    on_enable;
    update;
    late_update;
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

