//
// A tiny (mostly) typeless undo.
//
// thanks https://rxi.github.io/a_simple_undo_system.html
// (the comments in this file are mostly rxi's)
//
// Note: items we track must be stable in memory, i.e., their addresses cannot
// change.
//

//
// TODO: max undo stack size
// TODO: use Any or Type_Info*s to maintain more metadata for UI?
//

VERBOSE :: false;

Impl :: struct {
    undo: [..]Item; // Stores changes that can be undone
    redo: [..]Item; // Stores undone changes which can be redone
    temp: [..]Item; // Stores copies of all blocks of data passed to undo.push since the last commit

    needs_save: bool;
}

Item :: struct {
    action: Action;

    pointer: *void; // pointer to the data's location in memory

    size: int;      // size in bytes of the data

    data: *void;    // copy of the data before it was modified
    union {
        resizable_array: Resizable_Array; // used for Array_Replacement
        str: string; // used for String_Replacement
    }

    source_code_location: Source_Code_Location;
}

Action :: enum u8 {
    End_Of_Sequence :: 0;
    Mem_Copy :: 1;
    Array_Replacement :: 2;
    String_Replacement :: 3;
}

can_undo :: (impl: *Impl) -> bool {
    return impl.undo.count > 0;
}

can_redo :: (impl: *Impl) -> bool {
    return impl.redo.count > 0;
}

add_temp_item :: (temp: *[..]Item, action: Action, data_pointer: *void, loc := #caller_location) -> *Item {
    item := array_add(temp);
    item.action = action;
    item.pointer = data_pointer;
    item.source_code_location = loc;
    return item;
}

push_string :: (using impl: *Impl, str: *string, loc := #caller_location) {
    assert(str != null);

    for temp if it.pointer == str {
        assert(it.action == .String_Replacement);
        return;
    }

    item := add_temp_item(*temp, .String_Replacement, str, loc=loc);
    item.size = str.count;
    item.source_code_location = loc;
    item.str = <<str;
    
    item.str.data = alloc(item.str.count);
    memcpy(item.str.data, str.data, str.count);
}

push_array :: (using impl: *Impl, array: *[..]$T, loc := #caller_location) {
    #if VERBOSE log("undo.push_array % - %", T, array);

    // don't push more than once for the same array.
    for temp if it.pointer == array {
        assert(it.action == .Array_Replacement);
        return;
    }

    item := add_temp_item(*temp, .Array_Replacement, array, loc=loc);
    item.size = size_of(T);
    item.resizable_array = <<cast(*Resizable_Array)array;
    assert(item.resizable_array.allocated == array.allocated);

    // We store a copy of the data to compare later.
    item.resizable_array.data = alloc(array.allocated * item.size, array.allocator);
    memcpy(item.resizable_array.data, array.data, array.count * item.size);

    //print("push_array copied % bytes from % to temp %\n", array.count * item.size, array.data, item.resizable_array.data);
}

// A copy of array_reserve from Array.jai, but without the polymorphic
// argument. You have to specify the item_size at runtime.
array_reserve_runtime_size :: (array: *Resizable_Array, desired_items: s64, item_size: int) {
    assert(item_size > 0);
    assert(array.allocator != null);
    //print("array_reserve_runtime_size got data %\n", array.data);
    assert(array.data != null); // Program will die if we couldn't get memory. We can think about an alternative strategy, but it's hard to know what would be reasonable.

    array.allocated = desired_items;
}

array_reset :: (using impl: *Impl, array: *[..]$T) {
    if impl == null {
        array_reset(array);
        return;
    }

    if array.count == 0
        return; // TODO: this is different behaviour than in the real array_reset.

    push_array(impl, array);

    //array_reset(array);

    // TODO: this is probably a leak. use the main() method here with an
    // allocation tracker to figure out ownership stuff with tracking array
    // changes.
    array.count = 0;
    array.allocated = 0;
    array.data = null;

    //print("Undo.array_reset(%,\n  item=%\n  size=%)\n", array, <<array, <<item, item.size);
    //print_hex_bytes(array.data, array.count * item.size);
}

push :: (impl: *Impl, obj: *$T, loc := #caller_location) {
    #if VERBOSE log("undo.push: %", <<obj);

    // This undo.push() overload accepts a pointer to any type, and will get
    // the Type_Info's runtime size for you.

    push(impl, obj, type_info(T).runtime_size, loc=loc);
}

push :: (using impl: *Impl, obj_data: *void, size_in_bytes: int, loc := #caller_location) {

    // The undo.push() function takes a pointer and size value. When it is
    // called the temp stack is first scanned to check if we already have an
    // item for the given data block — if so the function already has the
    // old-data for this commit and can return without doing anything.
    // Otherwise — if the data is not on the temp stack — we push an item for
    // the given pointer and size: pushing the data at the pointer, the pointer
    // itself and finally the size of the data block.

    assert(obj_data != null, "undo.push given a null pointer");
    
    for * temp {
        if it.action == .Mem_Copy && obj_data == it.pointer {
            if it.size < size_in_bytes
                it.size = size_in_bytes; // it is legal to push the same pointer, with a bigger size.
            return; // We can return without doing anything, since we already noted the state.
        }
    }

    item := add_temp_item(*temp, .Mem_Copy, obj_data, loc=loc);
    item.data = alloc(size_in_bytes);
    memcpy(item.data, obj_data, size_in_bytes);
    item.size = size_in_bytes;
}

commit :: (using impl: *Impl) {
    #if VERBOSE {
        log("undo.commit");
        print_stack_trace(context.stack_trace);
    }

    // When undo.commit() is called each item is popped from the temp stack and
    // the stored data is compared to the current data at the item's pointer.
    // Any differences are pushed as items to the undo stack. When the first
    // change is encountered the redo stack is reset and a null item is pushed
    // to the undo stack — this item is used to indicate the beginning of this
    // commit.

    first_change := true;
    while temp.count != 0 {
        temp_item := pop(*temp);
        
        if temp_item.action == {
            case .Mem_Copy;
                if memcmp(temp_item.data, temp_item.pointer, temp_item.size) == 0 {
                    free_item(temp_item);
                    continue;
                }

                //print("committing Mem_Copy % %\n", temp_item.size, temp_item.pointer);

            case .Array_Replacement; 
                arr := cast(*Resizable_Array)temp_item.pointer;
                temp_arr := temp_item.resizable_array;

                if temp_arr.allocator.proc != null {
                    assert(temp_arr.allocator.proc == arr.allocator.proc, "allocators did not match for arr %: % vs %", arr, temp_arr.allocator, arr.allocator);
                    assert(temp_arr.allocator.data == arr.allocator.data);
                }
                assert(temp_arr.data != arr.data);

                if temp_arr.count == arr.count && 
                    temp_arr.allocated == arr.allocated &&
                    memcmp(temp_arr.data, arr.data, temp_arr.count * temp_item.size) == 0
                {
                    free_item(temp_item);
                    continue;
                }

                //print("committing Array_Replacement % %\n", temp_arr.count * temp_item.size, arr.data);

            case .String_Replacement;
                str := cast(*string)temp_item.pointer;
                temp_str := temp_item.str;
                assert(temp_str.data != str.data);
                if temp_str.count == str.count &&
                    (<<str) == temp_str {

                    free_item(temp_item);
                    continue;
                }

            case .End_Of_Sequence;
                assert(false, "not sure what to do here");
        }
                
        if first_change {
            needs_save = true;

            first_change = false;
            null_item := array_add(*undo); // null item marks this commit

            for redo free_item(it);
            array_reset(*redo); // (note this is the actual array_reset, not ours)
        }

        array_add(*undo, temp_item);
    }
}

mark_needs_save :: (impl: *Impl, needs_save: bool) {
    impl.needs_save = needs_save;
}

free_item :: (item: Item) {
    if item.action == {
        case .End_Of_Sequence;
            assert(item.data == null);
            assert(item.resizable_array.data == null);
        case .Mem_Copy;
            free(item.data);
        case .Array_Replacement;
            assert(
                (cast(*Resizable_Array)item.pointer).data != item.resizable_array.data,
                "the undo Item's copied data pointer shouldn't be equal to the original's"
            );
            free(item.resizable_array.data, item.resizable_array.allocator);
        case .String_Replacement;
            assert(
                (cast(*string)item.pointer).data != item.str.data,
                "the undo Item's copied data pointer shouldn't be equal to the original string's");
    }
}

push_scope :: (impl: *Impl, objs: ..*$T) #expand {
    // A macro for calling push() now and commit() at the end of the current
    // scope.

    for objs push(impl, it);
    `defer commit(impl);
}

try_undo :: (using impl: *Impl) -> bool {
    if can_undo(impl) {
        _undo(impl);
        return true;
    }

    return false;
}

try_redo :: (using impl: *Impl) -> bool {
    if can_redo(impl) {
        _redo(impl);
        return true;
    }
    return false;
}

undo :: (using impl: *Impl) {
    // When undo.undo() is called each item on the undo stack is popped until
    // the null item is reached. The data stored for each item is pushed to the
    // redo stack so that it can be redone and the item's data is copied to the
    // location of the item's stored pointer such as to restore its old state.

    assert(undo.count > 0, "No items in the undo stack");
    
    pop_apply_and_push(*undo, *redo);
}

redo :: (using impl: *Impl) {
    // The implementation of undo.redo() is identical to that of undo.undo() but with
    // the roles of the undo and redo stacks swapped.
    assert(redo.count > 0, "No items in the redo stack");

    pop_apply_and_push(*redo, *undo);
}

#scope_file
_undo :: undo;
_redo :: redo; // the compiler is being weird about "undo" and "redo" as variables here...

print_hex_bytes :: (data: *void, size_in_bytes: int) {
    s: []u8;
    s.data = data;
    s.count = size_in_bytes;
    print_hex_bytes(s);
}

print_hex_bytes :: (data: []u8) {
    count := 0;
    for data {
        print("% ", formatInt(it, base=16, minimum_digits=2));
        count += 1;
        if count >= 8 {
            count = 0;
            print("\n");
        }
    }
    print("\n");
}



#import "Basic";

pop_apply_and_push :: (from_stack: *[..]Item, to_stack: *[..]Item) {
    assert(from_stack.count > 0);

    first_item := true;
    while true {
        item := pop(from_stack);
        if item.action == .End_Of_Sequence {
            assert(item.data == null);
            break;
        }

        if first_item {
            null_item := array_add(to_stack); // null item indicates new sequence
            first_item = false;
        }

        if item.action == {
            case .Mem_Copy;
                assert(item.data != null);

                // Save the data as is
                saved_data := alloc(item.size);
                memcpy(saved_data, item.pointer, item.size);

                // Transfer the old saved data into memory
                memcpy(item.pointer, item.data, item.size);

                //print("reverting Mem_Copy % bytes from % into %\n", item.size, item.data, item.pointer);

                // Store saved as-is data for later.
                free(item.data);
                item.data = saved_data;

            case .Array_Replacement;
                arr := cast(*Resizable_Array)item.pointer;
                // we noted the size_of this array's T
                // before, even though we don't have it now.

                // Note the current state of the array.
                saved_array:Resizable_Array = <<(cast(*Resizable_Array)arr);

                // Restore the old array state.
                <<arr = item.resizable_array;

                // @Leak SHOULD THIS BE REALLOC?
                arr.data = alloc(arr.count * item.size);
                //arr.data = realloc(arr.data, item.resizable_array.allocated * item.size, arr.allocated * item.size, arr.allocator, arr.allocator_data);
                memcpy(arr.data, item.resizable_array.data, arr.count * item.size);

                //print("reverting Array_Replacement % bytes from % into %\n",
                    //arr.count * item.size, item.resizable_array.data, arr.data);
                //print("restoring (size=%) count % and data ptr % to array %\n", item.size, item.resizable_array.count, item.resizable_array.data, arr);
                //print_hex_bytes(arr.data, arr.count * item.size);

                // The redo (or undo, if we're redoing) stack will get the current item.
                item.resizable_array = saved_array;

            case .String_Replacement;
                str := cast(*string)item.pointer;

                // Note the current state of the string.
                saved_str := <<str;

                // Restore the old string state.
                <<str = item.str;

                // @Leak SHOULD THIS BE REALLOC?
                str.data = alloc(str.count);
                memcpy(str.data, item.str.data, str.count);

                item.str = saved_str;
        }

        array_add(to_stack, item);
    }
}


test_undo :: () {
    impl: Impl;

    {

        arr: [..]int;
        array_add(*arr, 5, 6, 7, 8);
        assert(arr.count == 4);
        
        array_reset(*impl, *arr); // Note: this is this file's 'array_reset' procedure.
        assert(arr.count == 0);
        assert(arr.data == null);

        assert(impl.undo.count == 0);
        commit(*impl);

        assert(impl.undo.count == 2); // 1 for the "null" marker, and another for our array modification.
        assert(impl.undo[1].action == .Array_Replacement);
        undo(*impl);
        assert(impl.undo.count == 0);
        assert(arr.count == 4, "undo did not restor array count to 4: %", arr.count);
        assert(arr[0] == 5);
        assert(arr[1] == 6);
        assert(arr[2] == 7);
        assert(arr[3] == 8);

        assert(impl.redo.count == 2);
        redo(*impl);
        assert(arr.count == 0, "expected redoing the action to zero out the array count, but it was %", arr.count);
        assert(arr.data == null);
    }

    {
        Bar :: struct { val: int; };
        Foo :: enum {
            None;
            A;
            B;
        }

        Entry :: struct {
            foo: Foo;
            bar: *Bar;
        }

        bar1: Bar = .{val=42};

        entries: [..]Entry;
        entry := array_add(*entries);
        entry.foo = .B;
        entry.bar = *bar1;

        array_reset(*impl, *entries);
        commit(*impl);
        assert(entries.count == 0);

        undo(*impl);
        assert(entries.count == 1);
        assert(entries[0].foo == .B);
        assert(entries[0].bar == *bar1);
    }
    {
        arr: [..]int;
        array_add(*arr, 5);
        push_array(*impl, *arr);

        arr[0] = 6;
        commit(*impl);

        undo(*impl);
        assert(arr[0] == 5);
        redo(*impl);
        assert(arr[0] == 6);
        undo(*impl);
        assert(arr[0] == 5);

    }

    print("OK!");


}

#scope_export
main :: () { test_undo(); }
