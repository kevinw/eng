# jai wishlist

## for loop over range where you're using an unsigned int-1

## parser

```
Foo :: struct {
} @note

// the above is legal, but the below is not:

Foo :: struct {
    struct {} @note
}
```

## standard library

- Rename `__temp_allocator` to `temp_allocator`.
- `Window_Creation`
    - needs a way to catch your own (win32, etc...) events
    - multiple window support
- func(.Float2 | .Float3) doesn't work but func(MyEnum.Float2 | .Float3) does
