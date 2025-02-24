ROBUSTNESS_CHECKS :: false; // can this go away now?

/*
The point of this data structure is to have a bucket of things with pointers that never move,
for which you can add and remove elements in O(1).

We use virtual memory to reserve enough address space for some maximum value.

A freelist in the empty slots keeps adding and removing fast.
*/

Handle_Type :: struct {
    id: u32;
    generation: s32; @noserialize
};

operator == :: (a: Handle_Type, b: Handle_Type) -> bool {
    return a.id == b.id && a.generation == b.generation;
}

operator != :: (a: Handle_Type, b: Handle_Type) -> bool {
    return a.id != b.id || a.generation != b.generation;
}

Array_With_Holes :: struct(Value: Type) {
    Handle :: Handle_Type;
    Value_Type :: Value;
    Max_Bytes :: 1000 * size_of(Slot);
    Slot :: struct {
        // TODO: bring this union back, once the bug in beta 37 is fixed. it
        // causes a weird infinite loop of reporting redclared 'next' and
        // 'value' variables here...

        //union  {
            value: Value;
            next: u32;       // offset from beginning of array
        //}
        generation: s32;
    }

    debug_name: string;

    count: u32; // not the actual count of active items; it's the count of
                // allocated space for the following field 'items'. we can
                // consider maintaining a separate "active_count" or something
                // if we need it...

    items: []Slot;
}

#if ROBUSTNESS_CHECKS {
    get_page_size :: () -> u32 {
        #import "Windows";
        sys_info: SYSTEM_INFO;
        GetSystemInfo(*sys_info);
        return sys_info.dwPageSize;
    }

    get_originally_virtualalloced_pointer :: (arr: *$A/Array_With_Holes) -> *void {
        return cast(*void)arr.items.data - page_size + size_of(A.Slot);
    }
} else {
    get_originally_virtualalloced_pointer :: (arr: *$A/Array_With_Holes) -> *void {
        return cast(*void)arr.items.data;
    }
}

count_items :: (arr: *$A/Array_With_Holes) -> int {
    // TODO: the array should probably just keep an "active count" around.
    count := 0;
    for * arr count += 1;
    return count;
}

deinit_array_with_holes :: (arr: *$A/Array_With_Holes, $DEBUG_PROTECT_FREED_MEMORY:bool = false) {
    assert(arr != null);

    valloc_ptr := get_originally_virtualalloced_pointer(arr);
    VirtualFree(valloc_ptr, 0, MEM_RELEASE);

    if DEBUG_PROTECT_FREED_MEMORY print("TODO: DEBUG_PROTECT_FREED_MEMORY\n");
}

init_array_with_holes :: (arr: *$A/Array_With_Holes, debug_name := "no-name") {
    assert(arr.items.data == null, "Array_With_Holes was already initialized");

    #if ROBUSTNESS_CHECKS {
        page_size := get_page_size();
        assert(size_of(A.Slot) < page_size, "Slot is bigger than a page!");
    } else {
        page_size :: 0;
    }

    valloc_ptr := VirtualAlloc(null, cast(u64)A.Max_Bytes + page_size - size_of(A.Slot), MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE); // TODO: don't MEM_COMMIT till we actually need the page
    // /print("VirtualAlloc original pointer at %\n", valloc_ptr);

    #if ROBUSTNESS_CHECKS {
        assert(page_size > 0);
        old_protect_flags: u32;
        res := VirtualProtect(valloc_ptr, page_size, PAGE_NOACCESS, *old_protect_flags);
        assert(res != 0, "VirtualProtect failed");

        //old_ptr := arr.items.data;

        // the intent here is to make the freelist slot a protected page,
        // except when we explictly unlock it. so we place the first slot on
        // the protected page. see also get_originally_virtualalloced_pointer
        arr.items.data = cast(*A.Slot)((cast(*void)valloc_ptr) + page_size - size_of(A.Slot));

        //old_ptr.generation = 42; // should crash
    } else {
        arr.items.data = valloc_ptr;
    }

    assert(arr.items.data != null);
    arr.items.count = 1;

    {
        unlock_freelist(arr);
        arr.items[0].generation = SENTINEL_GENERATION;
    }

    arr.debug_name = copy_string(debug_name);
    //print("init_array_with_holes % items at %\n", debug_name, arr.items);

}

#if ROBUSTNESS_CHECKS {
unlock_freelist :: (arr: *$A/Array_With_Holes) #expand {

    #import "windows_ex";

    assert(arr != null && arr.items.data != null);
    page_size := get_page_size();
    alloc_ptr := (cast(*void)arr.items.data) - (page_size - size_of(A.Slot));

    //mem_basic_info: MEMORY_BASIC_INFORMATION;
    //sz := VirtualQuery(alloc_ptr, *mem_basic_info, size_of(MEMORY_BASIC_INFORMATION));
    //assert(sz != 0);

    old_protect: u32;

    new_protect:u32 = PAGE_READWRITE;
    //print("unlocking % bytes at %\n", page_size, alloc_ptr);
    res := VirtualProtect(alloc_ptr, page_size, new_protect, *old_protect);
    assert(res != 0, "VirtualProtect failed to unlock memory at %", alloc_ptr);
    assert(new_protect != old_protect, "VirtualProtect unlock failed to change protect flags");

    `defer {
        //print("locking back %\n", alloc_ptr);
        res = VirtualProtect(alloc_ptr, page_size, PAGE_NOACCESS, *old_protect);
        assert(res != 0, "VirtualProtect failed to re-lock memory at %", alloc_ptr);
    }
}

} else {
    unlock_freelist :: (arr: *$A/Array_With_Holes) #expand {

    }

}

reset :: (arr: *$A/Array_With_Holes) {
    for * arr.items {
        if it_index > 0 {
            it.generation = 0;
            it.next = 0;
        }
    }

    {
        unlock_freelist(arr);
        arr.items[0].next = 0;
        arr.items[0].generation = SENTINEL_GENERATION;
    }

    arr.count = 0;
    arr.items.count = 1;
}

SENTINEL_GENERATION  :: 999999;

allocate_slot :: (arr: *$A/Array_With_Holes, undo: *Undo.Impl = null) -> (A.Handle, *A.Value_Type) {
    assert(arr.items.data != null, "Array_With_Holes was not initialized");
    slot_index: u32;
    {
        unlock_freelist(arr);
        assert(arr.items[0].generation == SENTINEL_GENERATION);
        if undo Undo.push(undo, *arr.items[0]);
        slot_index = arr.items[0].next;
        arr.items[0].next = arr.items[slot_index].next;
    }

    if slot_index != 0 {
        if undo Undo.push(undo, *arr.items[slot_index]);
        assert(arr.items[slot_index].generation <= 0);
        arr.items[slot_index].generation *= -1;
    } else {
        // If it was zero, the freelist is empty.
        if undo Undo.push(undo, *arr.count);
        if undo Undo.push(undo, *arr.items.count);
        arr.count += 1;
        arr.items.count += 1;
        assert(size_of(A.Slot) * arr.count < A.Max_Bytes);
        slot_index = cast(u32)arr.count;  // here we intentionally don't subtract one, to account for the freelist slot at 0

        _slot := *arr.items[slot_index];
        if undo Undo.push(undo, _slot);
        _gen  := _slot.generation;
        assert(_gen == 0);
    }

    assert(slot_index != 0);
    arr.items[slot_index].generation += 1;
    assert(arr.items[slot_index].generation > 0);

    handle: A.Handle;
    handle.id = slot_index;
    handle.generation = arr.items[slot_index].generation;

    value_ptr := *arr.items[slot_index].value;
    Construct(value_ptr, A.Value_Type);

    #if ROBUSTNESS_CHECKS {
        test_handle := get_handle_for_value_ptr(arr, value_ptr);
        assert(get_item_ptr(arr, test_handle) == value_ptr);
    }

    return handle, value_ptr;
}

get_handle_for_value_ptr :: (arr: *$A/Array_With_Holes, value_ptr: *A.Value_Type) -> A.Handle {
    // TODO: not sure this should even exist. don't we want to store handles
    // everywhere anyways?

    assert(value_ptr != null, "You passed a null value_ptr to get_handle_for_value_ptr");
    assert(value_ptr >= *arr.items[1].value, "You passed a value_ptr that was too low to get_handle_for_value_ptr");
    assert(value_ptr <= *arr.items[arr.count].value);

    diff := (cast(*A.Slot)value_ptr - cast(*A.Slot)*arr.items[1].value);
    slot_index := diff + 1;

    assert(slot_index > 0, "slot index must be greater than 0: %", slot_index);
    assert(slot_index <= arr.count, "derived slot_index was %, but arr.count was %", slot_index, arr.count);

    handle: Handle_Type;
    handle.id = cast(u32)slot_index;
    assert(slot_index != 0);
    handle.generation = arr.items[slot_index].generation;
    assert(handle.generation > 0, "expected entity pointer to have a valid generation, but it was %", handle.generation);

    assert(get_item_ptr(arr, handle) == value_ptr);

    return handle;
}

delete_item :: (arr: *$A/Array_With_Holes, handle: A.Handle, undo: *Undo.Impl = null) -> bool {
    assert(arr.items.data != null, "Array_With_Holes was not initialized");
    {
        unlock_freelist(arr);
        assert(arr.items[0].generation == SENTINEL_GENERATION);
    }

    assert(handle.id > 0, "delete_item(handle=%)", handle);
    assert(handle.id <= arr.count);
    assert(handle.generation > 0);

    slot := *arr.items[handle.id];
    assert(slot.generation > 0, "generation was % in slot % (handle expected gen %)", slot.generation, handle.id, slot.generation);

    // If it's already been deleted and we have a stale handle, just return
    // false.
    if handle.generation != slot.generation
        return false;

    if undo != null {
        /*
        print("[undo] ArrWHoles.delete_item % is noting freelist at % and slot at %\n",
            <<arr, *arr.items[0], slot);
        */

        // the freelist, and the slot we're writing to will change.
        if undo Undo.push(undo, *arr.items[0]);
        if undo Undo.push(undo, slot);
    }

    slot.generation *= -1;
    assert(slot.generation < 0);

    // Add to the freelist, which is stored in slot 0.
    {
        unlock_freelist(arr);
        assert(handle.id != 0, "handle id was zero");
        arr.items[handle.id].next = arr.items[0].next;
        arr.items[0].next = handle.id;
    }

    return true;
}

add_item :: (arr: *$A/Array_With_Holes, value: A.Value_Type) -> A.Handle {
    assert(arr.items.data != null, "Array_With_Holes was not initialized");

    handle := allocate_slot(arr);
    arr.items[handle.id].value = value;
    return handle;
}

get_item_ptr :: (arr: *$A/Array_With_Holes, handle: A.Handle, $check_count := false) -> *A.Value_Type {
    assert(arr.items.data != null, "Array_With_Holes was not initialized");
    {
        unlock_freelist(arr);
        assert(arr.items[0].generation == SENTINEL_GENERATION);
    }
    if handle.id <= 0
        assert(handle.id > 0, "You passed an uninitialized handle to Array_With_Holes.get_item_ptr");
    if handle.generation <= 0
        assert(handle.generation > 0, "You passed handle to get_item_ptr: %", handle);

    #if check_count {
        if handle.id >= arr.items.count
            return null;
    }

    slot := *arr.items[handle.id];
    if slot.generation == handle.generation
        return *slot.value;
    return null;
}

set :: inline (arr: *$A/Array_With_Holes, handle: A.Handle, value: A.Value_Type) {
    assert(arr.items.data != null);
    {
        unlock_freelist(arr);
        assert(arr.items[0].generation == SENTINEL_GENERATION);
    }

    arr.items[handle.id].value = value;
}

HandleIterator :: struct(A: Type) {
    arr: *A;
}

handles :: (arr: *$A/Array_With_Holes) -> HandleIterator(A) {
    assert(arr != null);
    iter: HandleIterator(A);
    iter.arr = arr;
    return iter;
}

//
// Iterate through the non-dead handles in the bucket.
//
for_expansion :: (handles: *HandleIterator($A), body: Code, flags: For_Flags) #expand {
    arr := handles.arr;
    assert(arr != null);
    {
        unlock_freelist(arr);
        assert(arr.items[0].generation == SENTINEL_GENERATION,
            "gen (address %) of first item for % at root addr % was not %: %",
                *arr.items[0].generation, arr.debug_name, *arr.items, SENTINEL_GENERATION, arr.items[0].generation);
    }
    #assert !(flags & .REVERSE);

    index := 0;
    n := 1; // start at one to ignore the first freelist hole
    while n <= arr.count {
        slot_index := cast(u32)n;
        slot := *arr.items[n];
        n += 1;
        
        if slot.generation <= 0 continue; // dead

        `it: Handle_Type;
        `it.id = slot_index;
        `it.generation = slot.generation;
        `it_index := index; // TODO: not sure it_index is useful here...

        #insert body;

        index += 1;
    }
}

//
// Iterate through the non-dead values of the bucket.
//
for_expansion :: (arr: *$A/Array_With_Holes, body: Code, flags: For_Flags) #expand {
    assert(arr.items.data != null);
    {
        unlock_freelist(arr);
        assert(arr.items[0].generation == SENTINEL_GENERATION,
            tprint("gen (address %) of first item for % at root addr % was not %: %",
                *arr.items[0].generation, arr.debug_name, arr.items, SENTINEL_GENERATION, arr.items[0].generation));
    }

    #assert !(flags & .REVERSE);

    index := 0;
    n := 1; // start at one to ignore the first freelist hole
    while n <= arr.count {
        slot := *arr.items[n];
        n += 1;
        
        if slot.generation <= 0 continue; // dead

        #if flags & .POINTER {
            `it := *slot.value;
        } else {
            `it := slot.value;
        }
        `it_index := index; // TODO: not sure it_index is useful here...

        #insert body;

        index += 1;
    }

}

#if 0
main :: () {
    Debug :: #import "Debug";
    Debug.init();

    print("array with holes\n");

    my_arr: Array_With_Holes(int);
    init_array_with_holes(*my_arr, "test-arr");
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
Undo :: #import "undo";
#import "Basic";
#import "Windows";

