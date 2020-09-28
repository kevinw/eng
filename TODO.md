# TODO

1. Treat this TODO list as an actual plan. That means: check it before working,
   and after working. Mark down whether or not it was a "successful" work
   session.
2. Figure out what kind of thing you actually want to make. Take actions that
   directly lead to the result you want.

   For example:

   - If it's an action game, play with the controller always. Come up with a
     plan for an MVP and make it. Make someone play it. if it's fun, then keep
     making it. If it's not, try something else.




- `on_enable` needs to be called after all sibling components get added. Then I
  can fix Cam_Follow to set it's target position on startup.
- The meta-program should check the type of `on_enable` and give you a helpful
  error message if you forget the `*Entity` argument.
- @bug saving changes sometimes results in the DLL being loaded twice.
- Footsteps with reverb - going to need a way to do dynamic sound in this game
  about sound
- there's a thing in Unity where you add a public field, and then suddenly all
  of your serialized objects have the value of that field. here i'm doing a
  different thing where you get the default. which I think is better. but
  there's an even further thing I could do, which is...during a build, if
  there's never anything that changes that field, why not make it a constant?
  the code could be more efficient. I suppose it'd be tough to know 100% for
  sure, but if that `Type_Info_Struct_Member` was never written to, and no WBML
  that we use ever overwrites it, we should be good. right?

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
