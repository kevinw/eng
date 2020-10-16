# TODO

## Right Now
- change level layout
- use a different background (flipping through images)
- change the UV background shader a bit
- add some grass decorations
- show demo of picking up player, moving the plant
- POST ON HANDMADE DISCORD

## High Priority
- Sort this list (difficulty? MVP for shippable thing?)
- Watch videos and read blogs about and take notes on Peek, Roblox, and Dreams
  editing tools
- join the [berlin minigame jam discord](https://discord.gg/evM44ns)
- Sort this list (difficulty? MVP for shippable thing?)
- make sure that stack traces are working and if they aren't report a bug
- Make the editor reload the last saved scene. Each game could have a “default
  scene to load”
- Make the editor prompt you to save changes to a scene on exit.
- 1 hour chipping away at the [game design
  curriculum](https://www.riotgames.com/en/urf-academy/curriculum-guide)
- Ask: what GIF to share on the Jai discord or handmade discord that would get
  some attention
- Actually put the speaker in. Have your distance show as a circle on screen
  for the maximum radius it affects you.
- Maybe show the current task in the game as an overlay 
- Figure out how Link should work and make it work!
- ImGui compiler node visualizer (bonus points for using the node editor)
- `on_enable` needs to be called after all sibling components get added. Then I
  can fix `Cam_Follow` to set it's target position on startup.
- Make sure the WBML only shows the color tint change. (This is the hard one.)
  - First do the dumbest thing possible. When calculating the "default" when
    serializing the WBML for an instantiated prefab, load the prefab! And use
    those bytes for comparison!
- Vim in-line errors again. It'd be nice to do something simple where the
  game's invocation of the Jai compiler writes its output to a file that Vim
  knows to look for.
    set errorformat=%f:%l\,%c:\ %m
    set make=type\ .compiler_errors

  ok so that turned out to be complicated. try making a Jai ALE plugin that
  just reads the output of the text file

## Medium Priority
- What would it really take to drop raylib as a dependency? Actually--maybe I
- ImGui bindings need a coherent string interface. Ideally, taking strings
  everywhere would be good.
  we could do it piece by piece. Start with something simple like
  `Shape_Renderer`
- Don't make an engine. Make a game. Find a way to center that.
- Instanced rendering
- Chipmunk physics
- 2 hour timer; procreate doodling
- Try catching windows touch events and make rotation of entities with two
  fingers work via iPad remote desktop
- research general “mistakes we made making this engine
- research network shared data stores. What would the minimum thing be.
- cleanup selection and undo
- What is the simplest possible frame graph blog post
- In the UI, the color field should have a different background color to
  indicate that the prefab is overridden. As a first attempt at implementing
  this.
- The meta-program should check the type of `on_enable` and give you a helpful
  error message if you forget the `*Entity` argument.
- @bug saving changes sometimes results in the DLL being loaded twice.
- Footsteps with reverb - going to need a way to do dynamic sound in this game
  about sound
- C library job systems
- Temporal anti-aliasing implementation 
- Motion blur implementation
- A function to take the type info from an old chunk of memory and "upgrade" it
- Bring sub libraries into the tree. Maybe instead of a sub module we have a
  python script that downloads the repos and copies the right files into lib/

## Low Priority
- Research binary pack formats; C libraries that do virtual file systems
- Idle thought: what if each component was a DLL and a compiler error in one
  wouldn’t necessarily halt the others
- There's a thing in Unity where you add a public field, and then suddenly all
  of your serialized objects have the value of that field. Here I'm doing a
  different thing where you get the default. Which I think is better. But
  there's an even further thing I could do, which is...during a build, if
  there's never anything that changes that field, why not make it a constant?
  The code could be more efficient. I suppose it'd be tough to know 100% for
  sure, but if that `Type_Info_Struct_Member` was never written to, and no WBML
  that we use ever overwrites it, we should be good. Right?
- A function for collecting the local variables of a function up until a
  certain AST node. This will be useful for two things:
    - a generator macro which can turn a function with `yield()` statements
      into an equivalent state machine. the locals need to be turned into a
      struct that can be passed into the function, and stored for later
      re-entry.
    - a `loglocals()` function which would be a quick way to throw local
      VARIABLES ONTO THE SCREEN.

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


# DONE

Prefabs and undo
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


* Draw a dumb animated tree in Aseprite.
* Hand code a tree prefab.
* Place several in the scene, changing their color tint.
