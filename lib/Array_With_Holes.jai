#import "Windows";

/*

The point of this data structure is to have a bucket of things with pointers that never move,
for which you can add and remove elements in O(1).

We use virtual memory to reserve enough address space for some maximum value.

A freelist in the empty slots keeps adding and removing fast.
*/

Handle_Type :: struct {
    id: u32;
    generation: s32;
};

Array_With_Holes :: struct(Value: Type, Max_Bytes_N: int = 4000) {
    Handle :: Handle_Type;
    Value_Type :: Value;
    Max_Bytes :: Max_Bytes_N;
    Slot :: struct(Value: Type) {
        union  {
            value: Value;
            next: u32;       // offset from beginning of array
        }
        generation: s32;
    }

    count: u32; // not the actual count of active items; it's the count of
                // allocated space for the following field 'items'. we can
                // consider maintaining a separate "active_count" or something
                // if we need it...

    items: *Slot;
}

init_array_with_holes :: (arr: *$A/Array_With_Holes) {
    arr.items = VirtualAlloc(null, cast(u64)A.Max_Bytes, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE); // TODO: don't MEM_COMMIT till we actually need the page
    assert(arr.items != null);
    arr.items[0].generation = SENTINEL_GENERATION;

}

SENTINEL_GENERATION  :: 999999;

allocate_slot :: (arr: *$A/Array_With_Holes) -> (A.Handle, *A.Value_Type) {
    assert(arr.items != null);
    assert(arr.items[0].generation == SENTINEL_GENERATION);

    slot_index := arr.items[0].next;
    arr.items[0].next = arr.items[slot_index].next;
    if slot_index != 0 {
        assert(arr.items[slot_index].generation <= 0);
        arr.items[slot_index].generation *= -1;
    } else {
        // If it was zero, the freelist is empty.
        arr.count += 1;
        assert(size_of(A.Slot) * arr.count < A.Max_Bytes);
        slot_index = cast(u32)arr.count;  // here we intentionally don't subtract one, to account for the freelist slot at 0
        assert(arr.items[slot_index].generation == 0);
    }

    arr.items[slot_index].generation += 1;
    assert(arr.items[slot_index].generation > 0);

    handle: A.Handle;
    handle.id = slot_index;
    handle.generation = arr.items[slot_index].generation;

    memory := *arr.items[slot_index].value;
    Construct(memory, A.Value_Type);

    return handle, memory;
}

delete_item :: (arr: *$A/Array_With_Holes, handle: A.Handle) -> bool {
    assert(arr.items != null);
    assert(arr.items[0].generation == SENTINEL_GENERATION);

    assert(handle.id > 0, "delete_item(handle=%)", handle);
    assert(handle.id <= arr.count);
    assert(handle.generation > 0);

    slot := *arr.items[handle.id];
    assert(slot.generation > 0, tprint("generation was % in slot % (handle expected gen %)", slot.generation, handle.id, slot.generation));

    // If it's already been deleted and we have a stale handle, just return
    // false.
    if handle.generation != slot.generation
        return false;

    slot.generation *= -1;
    assert(slot.generation < 0);

    // Add to the freelist, which is stored in slot 0.
    arr.items[handle.id].next = arr.items[0].next;
    arr.items[0].next = handle.id;

    return true;
}

add_item :: (arr: *$A/Array_With_Holes, value: A.Value_Type) -> A.Handle {
    handle := allocate_slot(arr);
    arr.items[handle.id].value = value;
    return handle;
}

get_item :: (arr: *$A/Array_With_Holes, handle: A.Handle) -> (bool, A.Value_Type) {
    assert(arr.items != null);
    assert(arr.items[0].generation == SENTINEL_GENERATION);

    assert(handle.id > 0);
    assert(handle.generation > 0);

    slot := arr.items[handle.id];
    if slot.generation == handle.generation
        return true, slot.value;
    
    return false, .{};
}

get_item_ptr :: (arr: *$A/Array_With_Holes, handle: A.Handle) -> *A.Value_Type {
    assert(arr.items != null);
    assert(arr.items[0].generation == SENTINEL_GENERATION);
    assert(handle.id > 0);
    assert(handle.generation > 0);

    slot := *arr.items[handle.id];
    if slot.generation == handle.generation
        return *slot.value;
    return null;
}

set :: inline (arr: *$A/Array_With_Holes, handle: A.Handle, value: A.Value_Type) {
    assert(arr.items != null);
    assert(arr.items[0].generation == SENTINEL_GENERATION);

    arr.items[handle.id].value = value;
}

for_expansion :: (arr: *$A/Array_With_Holes, body: Code, pointer: bool, reverse: bool) #expand {
    assert(arr.items != null);
    assert(arr.items[0].generation == SENTINEL_GENERATION);

    #assert(!reverse);

    index := 0;
    n := 1; // start at one to ignore the first freelist hole
    while n <= arr.count {
        slot := *arr.items[n];
        n += 1;

        if slot.generation < 0 continue; // dead

        #if pointer {
            `it := *slot.value;
        }
        else {
            `it := slot.value;
        }

        `it_index := index;
        #insert body;
        index += 1;
    }

}

#scope_file

test_array_with_holes :: () {
    print("array with holes\n");

    my_arr: Array_With_Holes(int);
    init_array_with_holes(*my_arr);
    slot := allocate_slot(*my_arr);
    set(*my_arr, slot, 42);
    assert(my_arr.items[slot.id].value == 42);

    slot2 := add_item(*my_arr, 55);
    assert(my_arr.items[slot2.id].value == 55);

    add_item(*my_arr, 66);
    slot3 := add_item(*my_arr, 77);
    print("slot3.id is %\n", slot3.id);
    add_item(*my_arr, 88);

    assert(my_arr.count == 5);
    delete_item(*my_arr, slot3);

    // a newly added item should go into the hole leftover by the 

    slot4 := add_item(*my_arr, 99);
    assert(slot3.id == slot4.id, "expected these to be equal: % and %", slot3.id, slot4.id);
    assert(slot3.generation != slot4.generation, "but these to be unequal: % and %", slot3.generation, slot4.generation);

    print("OK!\n");

    // TODO: test for_expansion
}

#scope_file
#import "Basic";