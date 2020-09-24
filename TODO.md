# TODO

- footsteps with reverb - going to need a way to do dynamic sound in this game about sound

## general Jai research projects

- a function to take the type info from an old chunk of memory and "upgrade" it
- A function for collecting the local variables of a function up until a certain AST node. this will be useful for two things:
    - a generator macro which can turn a function with `yield()` statements into an equivalent state machine. the locals need to be turned into a struct that can be passed into the function, and stored for later re-entry.
    - a `loglocals()` function which would be a quick way to throw local variables onto the screen.
