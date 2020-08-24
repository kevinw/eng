#import "Windows";

Handle_Type :: struct {
    // TODO: would like this to be inside the Array_With_Holes
    // struct for Handle type-safety. But a compiler bug is in the way
    // currently.
    id: u32;
    generation: u32;
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
        generation: u32;
    }

    items: *Slot;
    count: u32;
}



init_array_with_holes :: (arr: *$A) {
    arr.items = VirtualAlloc(null, cast(u64)A.Max_Bytes, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE); // TODO: don't MEM_COMMIT till we actually need the page
    assert(arr.items != null);
}

allocate_slot :: (arr: *$A) -> A.Handle {
    slot := arr.items[0].next;
    arr.items[0].next = arr.items[slot].next;
    if slot != 0 {
        handle: A.Handle;
        handle.id = slot;
        handle.generation = arr.items[slot].generation;
        return handle;
    }

    // If it was zero, the freelist is empty.
    arr.count += 1;
    assert(size_of(A.Slot) * arr.count < A.Max_Bytes);

    handle: A.Handle;
    handle.id = cast(u32)arr.count;  // here we intentionally don't subtract one, to account for the freelist slot at 0
    handle.generation = arr.items[arr.count].generation;
    return handle;
}

delete_item :: (arr: *$A, handle: A.Handle) {
    arr.items[handle.id].generation += 1; // advance this slot to the next generation

    // Add to the freelist, which is stored in slot 0.
    arr.items[handle.id].next = arr.items[0].next;
    arr.items[0].next = handle.id;
}

add_item :: (arr: *$A, value: A.Value_Type) -> A.Handle {
    slot := allocate_slot(arr);
    arr.items[slot.id].value = value;
    return slot;
}

set :: inline (arr: *$A, handle: A.Handle, value: A.Value_Type) {
    arr.items[handle.id].value = value;
}


main :: () {
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

    slot4 := add_item(*my_arr, 99);
    assert(slot3.id == slot4.id, "expected these to be equal: % and %", slot3.id, slot4.id);
    assert(slot3.generation != slot4.generation, "but these to be unequal: % and %", slot3.generation, slot4.generation);

    print("OK!\n");

}

#scope_file
#import "Basic";