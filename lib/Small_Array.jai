Small_Array :: struct(Value: Type) {
    NUM_STACK :: 4;
    Value_Type :: Value;
    union {
        heap_storage: [..]Value;
        stack_values: struct {
            count: s64;
            // Putting count first matches the layout of Resizable_Array in
            // Preload.jai and means we "share" it.
            items: [NUM_STACK]Value;
        };
        // Ditto the count comment above.
        count: s64;
    };
}

operator [] :: (arr: $S/Small_Array, i: int) -> S.Value_Type {
    if arr.count > S.NUM_STACK
        return arr.heap_storage[i];
    else
        return arr.stack_values.items[i];
}

is_on_heap :: (arr: *$S/Small_Array) -> bool {
    return arr.count > S.NUM_STACK;
}

array_add :: (arr: *$S/Small_Array) -> *S.Value_Type {
    arr.count += 1;
    if arr.count == S.NUM_STACK + 1 {
        print("moving to heap...\n");

        // First, copy the stack values somewhere so we don't overwrite them.
        copy: [S.NUM_STACK]S.Value_Type;
        for arr.stack_values.items
            copy[it_index] = it;

        arr.heap_storage.count = 0;
        arr.heap_storage.data = null;
        arr.heap_storage.allocated = 0;
        arr.heap_storage.allocator = null;
        arr.heap_storage.allocator_data = null;

        array_add(*arr.heap_storage, ..copy);
        assert(arr.heap_storage.count == S.NUM_STACK);

        return array_add(*arr.heap_storage);
    } else {
        return *arr.stack_values.items[arr.count - 1];
    }
}

array_add :: (arr: *$S/Small_Array, v: $V) {
    ptr := array_add(arr);
    << ptr = v;
}

for_expansion :: (arr: *$S/Small_Array, body: Code, pointer: bool, reverse: bool) #expand {
    #if pointer
        `it: *S.Value_Type;
    else
        `it: S.Value_Type;
    `it_index: int;

    if is_on_heap(arr) {
        for *=pointer <=reverse item, i: arr.heap_storage {
            it = item;
            it_index = i;
            #insert body;
        }
    } else {
        for *=pointer <=reverse item, i: arr.stack_values.items {
            it = item;
            it_index = i;
            #insert body;
        }
    }
}

#scope_file

main :: () {
    #import "Basic";
    my_ints: Small_Array(int);
    assert(!is_on_heap(*my_ints));
    array_add(*my_ints, 42);
    assert(!is_on_heap(*my_ints));
    assert(my_ints[0] == 42);

    array_add(*my_ints, 2);
    array_add(*my_ints, 3);
    array_add(*my_ints, 4);
    assert(!is_on_heap(*my_ints));

    array_add(*my_ints, 99);
    assert(is_on_heap(*my_ints));

    assert(my_ints[0] == 42);
    assert(my_ints[4] == 99);





}