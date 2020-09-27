# TODO

- `on_enable` needs to be called after all sibling components get added. Then I
  can fix Cam_Follow to set it's target position on startup.
- The meta-program should check the type of `on_enable` and give you a helpful
  error message if you forget the `*Entity` argument.
- @bug saving changes sometimes results in the DLL being loaded twice.
- Footsteps with reverb - going to need a way to do dynamic sound in this game
  about sound

## general Jai research projects

- a function to take the type info from an old chunk of memory and "upgrade" it
- A function for collecting the local variables of a function up until a
  certain AST node. this will be useful for two things:
    - a generator macro which can turn a function with `yield()` statements
      into an equivalent state machine. the locals need to be turned into a
      struct that can be passed into the function, and stored for later
      re-entry.
    - a `loglocals()` function which would be a quick way to throw local
      variables onto the screen.
