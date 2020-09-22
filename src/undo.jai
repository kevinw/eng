// thanks https://rxi.github.io/a_simple_undo_system.html
// (the comments in this file are rxi's)

// TODO: max undo stack size

// Note: items must be stable in memory, i.e., their addresses cannot change.

Impl :: struct {
    undo: [..]Item; // Stores changes that can be undone
    redo: [..]Item; // Stores undone changes which can be redone
    temp: [..]Item; // Stores copies of all blocks of data passed to undo_push since the last commit
}

Item :: struct {
    data: *void;    // copy of the data before it was modified
    pointer: *void; // pointer to the data's location in memory
    size: int;      // size in bytes of the data
}

can_undo :: (impl: *Impl) -> bool { return impl.undo.count > 0; }
can_redo :: (impl: *Impl) -> bool { return impl.redo.count > 0; }

push_scope :: (impl: *Impl, obj: *$T) #expand {
    push(impl, obj);
    `defer commit(impl);
}

push :: (impl: *Impl, obj: *$T) {
    push(impl, obj, type_info(T).runtime_size);
}

push :: (impl: *Impl, obj_data: *void, size_in_bytes: int) {
    // The undo_push() function takes a pointer and size value. When it is
    // called the temp stack is first scanned to check if we already have an
    // item for the given data block — if so the function already has the
    // old-data for this commit and can return without doing anything.
    // Otherwise — if the data is not on the temp stack — we push an item for
    // the given pointer and size: pushing the data at the pointer, the pointer
    // itself and finally the size of the data block.

    assert(obj_data != null, "undo_push given a null pointer");
    
    for impl.temp {
        if obj_data == it.data {
            assert(it.size == size_in_bytes, "You gave two different sizes for the same undo data pointer");

            // We can return without doing anything, since we already noted the state.
            return;
        }
    }

    temp_data := alloc(size_in_bytes);
    memcpy(temp_data, obj_data, size_in_bytes);

    item := array_add(*impl.temp);
    item.data = temp_data;
    item.pointer = obj_data;
    item.size = size_in_bytes;
}

commit :: (impl: *Impl) {
    // When undo_commit() is called each item is popped from the temp stack and
    // the stored data is compared to the current data at the item's pointer.
    // Any differences are pushed as items to the undo stack. When the first
    // change is encountered the redo stack is reset and a null item is pushed
    // to the undo stack — this item is used to indicate the beginning of this
    // commit.

    first_change := true;
    while impl.temp.count != 0 {
        temp_item := pop(*impl.temp);
        if memcmp(temp_item.data, temp_item.pointer, temp_item.size) == 0
            continue;

        if first_change {
            first_change = false;
            null_item := array_add(*impl.undo); // null item marks this commit

            for impl.redo free(it.data);
            array_reset(*impl.redo);
        }

        array_add(*impl.undo, temp_item);
    }
}

undo :: (impl: *Impl) {
    // When undo_undo() is called each item on the undo stack is popped until
    // the null item is reached. The data stored for each item is pushed to the
    // redo stack so that it can be redone and the item's data is copied to the
    // location of the item's stored pointer such as to restore its old state.

    assert(impl.undo.count > 0, "No items in the undo stack");

    first_item := true;
    while true {
        item := pop(*impl.undo);
        if item.data == null
            break;

        if first_item {
            null_item := array_add(*impl.redo); // null item indicating new redo sequence
            first_item = false;
        }

        // Save the current value for redo
        redo_data := alloc(item.size);
        memcpy(redo_data, item.pointer, item.size);

        // Undo the value
        memcpy(item.pointer, item.data, item.size);

        // Store redo for later.
        free(item.data);
        item.data = redo_data;
        array_add(*impl.redo, item);
    }
}

redo :: (impl: *Impl) {
    // The implementation of undo_redo() is identical to that of undo_undo() but with
    // the roles of the undo and redo stacks swapped.
    assert(impl.redo.count > 0, "No items in the redo stack");

    first_item := true;
    while true {
        item := pop(*impl.redo);
        if item.data == null
            break;

        if first_item {
            null_item := array_add(*impl.undo); // null item indicating new redo sequence
            first_item = false;
        }

        // Save the current value for undo
        undo_data := alloc(item.size);
        memcpy(undo_data, item.pointer, item.size);

        // Redo the value
        memcpy(item.pointer, item.data, item.size);

        // Store undo for later.
        free(item.data);
        item.data = undo_data;
        array_add(*impl.undo, item);
    }
}

#scope_file
#import "Basic";
