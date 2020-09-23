//
// A tiny typeless undo.
//
// thanks https://rxi.github.io/a_simple_undo_system.html
// (the comments in this file are mostly rxi's)
//
// Note: items must be stable in memory, i.e., their addresses cannot change.
//

//
// TODO: max undo stack size
// TODO: use Any or Type_Info*s to maintain more metadata for UI?
//

Impl :: struct {
    undo: [..]Item; // Stores changes that can be undone
    redo: [..]Item; // Stores undone changes which can be redone
    temp: [..]Item; // Stores copies of all blocks of data passed to undo.push since the last commit
}

Item :: struct {
    data: *void;    // copy of the data before it was modified
    pointer: *void; // pointer to the data's location in memory
    size: int;      // size in bytes of the data
}

can_undo :: (impl: *Impl) -> bool {
    return impl.undo.count > 0;
}

can_redo :: (impl: *Impl) -> bool {
    return impl.redo.count > 0;
}

push :: (impl: *Impl, obj: *$T) {
    // This undo.push() overload accepts a pointer to any type, and will get
    // the Type_Info's runtime size for you.

    push(impl, obj, type_info(T).runtime_size);
}

push :: (using impl: *Impl, obj_data: *void, size_in_bytes: int) {
    // The undo.push() function takes a pointer and size value. When it is
    // called the temp stack is first scanned to check if we already have an
    // item for the given data block — if so the function already has the
    // old-data for this commit and can return without doing anything.
    // Otherwise — if the data is not on the temp stack — we push an item for
    // the given pointer and size: pushing the data at the pointer, the pointer
    // itself and finally the size of the data block.

    assert(obj_data != null, "undo.push given a null pointer");
    
    for temp {
        if obj_data == it.data {
            assert(it.size == size_in_bytes, "You gave two different sizes for the same undo data pointer");

            // We can return without doing anything, since we already noted the state.
            return;
        }
    }

    item := array_add(*temp);
    item.data = alloc(size_in_bytes);
    memcpy(item.data, obj_data, size_in_bytes);
    item.pointer = obj_data;
    item.size = size_in_bytes;
}

commit :: (using impl: *Impl) {
    // When undo.commit() is called each item is popped from the temp stack and
    // the stored data is compared to the current data at the item's pointer.
    // Any differences are pushed as items to the undo stack. When the first
    // change is encountered the redo stack is reset and a null item is pushed
    // to the undo stack — this item is used to indicate the beginning of this
    // commit.

    first_change := true;
    while temp.count != 0 {
        temp_item := pop(*temp);
        if memcmp(temp_item.data, temp_item.pointer, temp_item.size) == 0
            continue;

        if first_change {
            first_change = false;
            null_item := array_add(*undo); // null item marks this commit

            for redo free(it.data);
            array_reset(*redo);
        }

        array_add(*undo, temp_item);
    }
}

push_scope :: (impl: *Impl, obj: *$T) #expand {
    // A macro for calling push() now and commit() at the end of the current
    // scope.

    push(impl, obj);
    `defer commit(impl);
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

#import "Basic";

pop_apply_and_push :: (from_stack: *[..]Item, to_stack: *[..]Item) {
    assert(from_stack.count > 0);

    first_item := true;
    while true {
        item := pop(from_stack);
        if item.data == null {
            break;
        }

        if first_item {
            null_item := array_add(to_stack); // null item indicates new sequence
            first_item = false;
        }

        // Save the data as is
        saved_data := alloc(item.size);
        memcpy(saved_data, item.pointer, item.size);

        // Transfer the old saved data into memory
        memcpy(item.pointer, item.data, item.size);

        // Store saved as-is data for later.
        free(item.data);
        item.data = saved_data;
        array_add(to_stack, item);
    }
}

