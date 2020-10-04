## worklog

2020-10-03
    -3 did NOT check TODO
    +1 made image selector work well
    +1 added a smaller font
    +1 fix an entity handle crash
    +1 fix an imgui crash
2020-10-02
    +1 checked TODO
    +1 got image drawing in IMGUI to work by having the shader not just sample the red channel
2020-09-29
    +1 fixed a new editor camera selection bug
    -3 did NOT check TODO


# META

1. Treat this TODO list as an actual plan. That means: check it before working,
   and after working. Mark down whether or not it was a "successful" work
   session.
2. Figure out what kind of thing you actually want to make. Take actions that
   directly lead to the result you want.

   For example:

   - If it's an action game, play with the controller always. Come up with a
     plan for an MVP and make it. Make someone play it. if it's fun, then keep
     making it. If it's not, try something else.

# TODO

- Figure out how Link should work and make it work!
* Draw a dumb animated tree in Aseprite.
* Hand code a tree prefab.
* Place several in the scene, changing their color tint.
- Make sure the WBML only shows the color tint change. (This is the hard one.)
  - First do the dumbest thing possible. When calculating the "default" when
  serializing the WBML for an instantiated prefab, load the prefab! And use
  those bytes for comparison!
- In the UI, the color field should have a different background color to
  indicate that the prefab is overridden. As a first attempt at implementing
  this.


# TODO (backburner)

- ImGui bindings need a coherent string interface. Ideally, taking strings
  everywhere would be good.
- `on_enable` needs to be called after all sibling components get added. Then I
  can fix `Cam_Follow` to set it's target position on startup.
- The meta-program should check the type of `on_enable` and give you a helpful
  error message if you forget the `*Entity` argument.
- @bug saving changes sometimes results in the DLL being loaded twice.
- Footsteps with reverb - going to need a way to do dynamic sound in this game
  about sound
- There's a thing in Unity where you add a public field, and then suddenly all
  of your serialized objects have the value of that field. Here I'm doing a
  different thing where you get the default. Which I think is better. But
  there's an even further thing I could do, which is...during a build, if
  there's never anything that changes that field, why not make it a constant?
  The code could be more efficient. I suppose it'd be tough to know 100% for
  sure, but if that `Type_Info_Struct_Member` was never written to, and no WBML
  that we use ever overwrites it, we should be good. Right?

## general Jai research projects

- a function to take the type info from an old chunk of memory and "upgrade" it
- A function for collecting the local variables of a function up until a
  certain AST node. This will be useful for two things:
    - a generator macro which can turn a function with `yield()` statements
      into an equivalent state machine. the locals need to be turned into a
      struct that can be passed into the function, and stored for later
      re-entry.
    - a `loglocals()` function which would be a quick way to throw local
      variables onto the screen.

# DONE

prefabs and undo
- prefab is 
```
{
    prefab_link "prefab_unique_name"

    // and overridden properties...
    x 42
    y 99

}
```

Making undoing a delete of an entity would mean exactly the same thing as
serializing an object as a prefab, and instantiating it.  Perhaps ids in the
context of serialized WBML can just be saved as they are in memory. but then
when instantiating them, they may get "reassigned". or is it simpler than that?
If undoing the deleting of an entity is just writing bytes again...

What are the simplest possible operations? Make an object. Save out the type
info. (hash the type info? and save that? and then be able to reference it
forever?)


