/*

Parse (and write to) a file full of Markdown TODOs like the following:

 - [ ] my incomplete task
 - [x] my complete task

*/

Todos_State :: struct {
    todos: [..]Todo_Item;
    todos_loaded := false;
}

Todo_Item :: struct {
    State :: enum {
        Incomplete;
        Complete;
    }
        
    state: State;
    text: string;
    loc: Source_Code_Location;
}

save_todo :: (using todos_state: *Todos_State, todo: *Todo_Item) -> bool {
    handler: Text_File_Handler;
    handler.do_version_number = false;
    defer deinit(*handler);

    filename := todo.loc.fully_pathed_filename;

    start_file(*handler, "todo_file_set", filename, optional=false);
    if handler.failed {
        print("save_todo handler failed: filename=%\n", filename);
        return false;
    }

    while true {
        line, found := consume_next_line(*handler);
        if handler.line_number != todo.loc.line_number
            continue;

        if !contains(line, todo.text) {
            log("error saving todo: line didn't contain todo text");
            return false;
        }

        idx, state := find_checkbox_markdown(line);
        if idx == -1 continue;

        // Replace the character
        character_to_change := slice(line, idx + "- [".count, 1);
        character_to_change[0] = cast(u8)(ifx todo.state == .Complete then #char "x" else #char " ");

        if !write_entire_file(filename, handler.orig_file_data) {
            log("error: could not write todo file '%'", filename);
            return false;
        }

        log("wrote todo on line %!\n", todo.loc.line_number);
        return true;
    }

    return false;
}

get_todos :: (using todos_state: *Todos_State) -> []Todo_Item {
    if todos_loaded
        return todos;

    todos_loaded = true;

    handler: Text_File_Handler;
    handler.do_version_number = false;
    defer deinit(*handler);

    found, exe_path, exe_name := split_by_character_from_right(get_path_of_running_executable(), #char "/");
    if !found {
        log("error: Unable to find my own executable?!");
        return .[];
    }

    filename := sprint("%/%", exe_path, TODO_FILENAME);
    log("parsing todos from '%'", filename);
    short_name := "todo_file";
    start_file(*handler, short_name, filename, false);
    if handler.failed {
        log("todo: handler failed");
        return .[];
    }

    while true {
        line, found := consume_next_line(*handler);
        if !found break;   // consume_next_line returns false for 'found' when we are done.

        idx, state := find_checkbox_markdown(line);
        if idx == -1 continue;

        todo := array_add(*todos);
        todo.text = copy_string(slice(line, idx + "- [ ]".count, 999999));
        todo.state = state;
        todo.loc.fully_pathed_filename = filename;
        todo.loc.line_number = handler.line_number;
    }

    return todos_state.todos;
}

#scope_file

#import "Text_File_Handler";
#import "String";
#import "System";
#import "File";

TODO_FILENAME :: "notes/TODO.md";

find_checkbox_markdown :: (line: string) -> (index: int, state: Todo_Item.State) {
    empty_idx   := index_of_string(line, "- [ ]");
    checked_idx := index_of_string(line, "- [x]");

    if empty_idx != -1
        return empty_idx, .Incomplete;
    else if checked_idx != -1
        return checked_idx, .Complete;
    else
        return -1, .Incomplete;
}

