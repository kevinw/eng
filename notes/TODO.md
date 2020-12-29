# TODO

## Immediate

- get 45 view rendering in. it will be satisfying to see that work and we're relatively close~!
    - the scene needs a camera component that will be used to actually draw things...
    - inspecting the camera should show its render texture. (or cycle between its 45?)
- make inverse projection mouse picking work. warning: mouse picking is potentially a rabbit hole...is there a simple CPU solution?

## High Priority
- flappy word - flappy bird mechanics, but you're swapping letters in words vertically
    - a column of characters. one or more words may be created from it. you're flapping the bird as you go, trying to fit into the gap that you create by removing a word.
- [HLSL shaders](https://github.com/microsoft/ShaderConductor) for other platforms
- [coroutines in C](https://www.chiark.greenend.org.uk/~sgtatham/coroutines.html)
- Join the [berlin minigame jam discord](https://discord.gg/evM44ns)
- make sure that stack traces are working and if they aren't report a bug
- Make the editor prompt you to save changes to a scene on exit.
- 1 hour chipping away at the [game design curriculum](https://www.riotgames.com/en/urf-academy/curriculum-guide)
- Maybe show the current task in the game as an overlay!
- Figure out how Link should work and make it work!
- ImGui compiler node visualizer (bonus points for using the node editor)
- `on_enable` needs to be called after all sibling components get added. Then I
  can fix `Cam_Follow` to set it's target position on startup.

## Medium Priority
- Watch videos and read blogs about and take notes on Peek, Roblox, and Dreams editing tools
- Don't make an engine. Make a game. Find a way to center that.
- Instanced rendering
- 2 hour timer; procreate doodling
- Try catching windows touch events and make rotation of entities with two fingers work via iPad remote desktop
- research general "mistakes we made making this engine"
- research network shared data stores. What would the minimum thing be.
- cleanup selection and undo
- In the UI, the color field should have a different background color to
  indicate that the prefab is overridden. As a first attempt at implementing
  this.
- @bug saving changes sometimes results in the DLL being loaded twice.
- C library job systems
- Temporal anti-aliasing implementation 
- Motion blur implementation
- A function to take the type info from an old chunk of memory and "upgrade" it
- Bring sub libraries into the tree. Maybe instead of a sub module we have a
  python script that downloads the repos and copies the right files into lib/

## Low Priority
- [delta time fix](https://blogs.unity3d.com/2020/10/01/fixing-time-deltatime-in-unity-2020-2-for-smoother-gameplay-what-did-it-take/)
- The meta-program should check the type of `on_enable` and give you a helpful
  error message if you forget the `*Entity` argument.
- add debug allocators to chipmunk
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


## research ideas:
    - "on change" component for reactive programming, or for GPU uploads
        think about GetWriteWatch(), or using exception guards on virtualalloc pages, to know whether we need to write stuff to the gpu or not...
    - [D3D11 Vendor Hacks](https://docs.google.com/spreadsheets/d/1J_HIRVlYK8iI4u6AJrCeb66L5W36UDkd9ExSCku9s_o/edit#gid=0)


