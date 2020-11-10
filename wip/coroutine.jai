simple :: () -> int {
    crBegin(#code struct {
        time_left: float;
    });

    print("in coro\n");

    crReturn(42);
    crFinish();
    print("did call finish\n");
}

crBegin :: (code: Code = .{}) #expand {
    `coro_ctx: struct {
        using #insert code;
        next_line: int;
    };

    #insert "if coro_ctx.next_line == {";
}

crFinish :: () #expand {
}

crReturn :: (val: $V, loc := #caller_location) #expand {
    `coro_ctx.next_line = loc.line_number;
    #insert "return val;";
    #insert tprint("case %", loc.line_number);
}

main_2 :: () {
    foo := "Don't print this";

    overwrite :: (var: Code) #expand {
        (#insert var) = "Print this!";
    }

    overwrite(#code foo);
    print("%", foo);
}


main :: () {
    simple();
}

#scope_file

#import "Basic";
