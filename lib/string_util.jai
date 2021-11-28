/// In place, turn "long_proc_name" into "Long Proc Name"
capitalize_and_spacify_snake_case :: (str: string) {
    s := str;
    capitalize_next := true;
    while s.count {
        if capitalize_next && s[0] != #char "_" {
            capitalize_next = false;
            s[0] = to_upper(s[0]);
        } else if s[0] == #char "_" {
            s[0] = #char " ";
            capitalize_next = true;
        }

        advance(*s, 1);
    }
}

#scope_file
#import "String";
#import "Basic";