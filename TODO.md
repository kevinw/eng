# TODO

## High Priority
- flappy word - flappy bird mechanics, but you're swapping letters in words vertically
- [delta time fix](https://blogs.unity3d.com/2020/10/01/fixing-time-deltatime-in-unity-2020-2-for-smoother-gameplay-what-did-it-take/)
- [HLSL shaders](https://github.com/microsoft/ShaderConductor)
- [coroutines in C](https://www.chiark.greenend.org.uk/~sgtatham/coroutines.html)
- add debug allocators to chipmunk
- Watch videos and read blogs about and take notes on Peek, Roblox, and Dreams
  editing tools
- Join the [berlin minigame jam discord](https://discord.gg/evM44ns)
- make sure that stack traces are working and if they aren't report a bug
- Make the editor reload the last saved scene. Each game could have a “default
  scene to load”
- Make the editor prompt you to save changes to a scene on exit.
- 1 hour chipping away at the [game design
  curriculum](https://www.riotgames.com/en/urf-academy/curriculum-guide)
- Maybe show the current task in the game as an overlay 
- Figure out how Link should work and make it work!
- ImGui compiler node visualizer (bonus points for using the node editor)
- `on_enable` needs to be called after all sibling components get added. Then I
  can fix `Cam_Follow` to set it's target position on startup.

## Medium Priority
- What would it really take to drop raylib as a dependency? Actually--maybe I
- ImGui bindings need a coherent string interface. Ideally, taking strings
  everywhere would be good.
  we could do it piece by piece. Start with something simple like
  `Shape_Renderer`
- Don't make an engine. Make a game. Find a way to center that.
- Instanced rendering
- 2 hour timer; procreate doodling
- Try catching windows touch events and make rotation of entities with two
  fingers work via iPad remote desktop
- research general "mistakes we made making this engine"
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
- Actually put the speaker in. Have your distance show as a circle on screen
  for the maximum radius it affects you.
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

