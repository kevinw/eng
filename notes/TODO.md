# TODO

- [x] an editor todo window
- [ ] fix mouse in new scene view
- [ ] fix mouse cursors on hover over splitters
- [ ] finish UV-from-shader to get corner dragging for rectangles!

## Immediate
- prototype 2dish uv displacement mapping like Yoku's Island Express?
- compute shaders https://youtu.be/0DLOJPSxJEg
- http://alextardif.com/Antialiasing.html
- https://www.youtube.com/watch?v=yG4ChOPyC-4
- https://rosenzweig.io/blog/asahi-gpu-part-2.html
- a world-space text render function with depth shadows
- a custom font for characters who don't speak your language
- light component with a gizmo
- many mesh renderers equals an instanced draw
- make rotation matrix work
- the [entity docs](https://www.ourmachinery.com/apidoc/plugins/entity/entity.h.html) for our machinery point towards using a "simulation context" for things like the preview window for a MeshRenderer
    - in general reading through their documentation seems like it would be 100% useful.
- ozz animation seems like a better "asset library" format. The-Forge seems to agree. in that case, assimp would just be another "loader"
    - just starting by using ozz to load a mesh would be more fun!
    - [this project](https://github.com/ColinGilbert/ozz-assimp-loader) converts assimp to ozz (the forge also does this I think)

- chipmunk klass vtable is out of date after a reload?
- Don't make an engine. Make a game. Find a way to center that.
- checkout noelfb's blah project for SpriteBatch inspiration, and for collision ideas
- [forward+ renderer](https://github.com/bcrusco/Forward-Plus-Renderer/tree/master/Forward-Plus/Forward-Plus/source/shaders)

## High Priority
- live reload DLL can crash if I save a jai change while another is building. we need a "is building" flag or something
- Materials
- Depth of field
    - Second: visualize intermediate textures easily with a single log call
- Make the editor prompt you to save changes to a scene on exit.
- Figure out how Link should work and make it work!
- automate structs for HLSL packing rules (maybe with a macro usable by other folks)
    - remember now that `#align 16` exists in Jai...might be an easy fix there.

## Medium Priority
- Color palettes
- swapchain/renderer rework - we need one renderer, but two swapchains
- reverse Z depth
- [coroutines in C](https://www.chiark.greenend.org.uk/~sgtatham/coroutines.html)
- mark draw-calls with [more debug APIs](https://seanmiddleditch.com/direct3d-11-debug-api-tricks/)
- try using Matrix4x3 
- Shader compile should result in a pink shader for fragments, and a passthrough vertex shader for vert
- Watch videos and read blogs about and take notes on Peek, Roblox, and Dreams editing tools
- 2 hour timer; procreate doodling
- Try catching windows touch events and make rotation of entities with two fingers work via iPad remote desktop
- In the UI, the color field should have a different background color to
  indicate that the prefab is overridden. As a first attempt at implementing
  this.
- C library job systems
- [Temporal anti-aliasing implementation](https://docs.google.com/document/d/15z2Vp-24S69jiZnxqSHb9dX-A-o4n3tYiPQOCRkCt5Q/edit)
- Motion blur implementation
- A function to take the type info from an old chunk of memory and "upgrade"
  it. Copy the type table of the outgoing DLL, and then patch based on that!?
  This would work for anything that has padding bytes at the end... would there
  be a way to automatically pad all structs? or is there something else I could
  do? Mark things as "pinned in memory, but upgradable." or "not pinned in
      memory, so feel free to memcopy them for me?" or getting into weird
      garbage collection territory where we walk the pointers starting from the
      context state?
- Bring sub libraries into the tree. Maybe instead of a sub module we have a
  python script that downloads the repos and copies the right files into lib/

## Low Priority
- [delta time fix](https://blogs.unity3d.com/2020/10/01/fixing-time-deltatime-in-unity-2020-2-for-smoother-gameplay-what-did-it-take/)
- [HLSL shaders](https://github.com/microsoft/ShaderConductor) for other platforms
- The meta-program should check the type of `on_enable` and give you a helpful
  error message if you forget the `*Entity` argument.
- add debug allocators to chipmunk
- Idle thought: what if each component was a DLL and a compiler error in one
  wouldn't necessarily halt the others
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
- Maybe show the current task in the game as an overlay!
- flappy word - flappy bird mechanics, but you're swapping letters in words vertically
    - a column of characters. one or more words may be created from it. you're flapping the bird as you go, trying to fit into the gap that you create by removing a word.


## Research
- [guide to implementing 2d platformers](http://higherorderfun.com/blog/2012/05/20/the-guide-to-implementing-2d-platformers/)
- [gorgeous top down visuals](https://twitter.com/HiWarp/status/1356809034213564416)
- Research binary pack formats; C libraries that do virtual file systems
- 2d parallax mapping textures with view dependent lighting
- game design books like Jesse Schnell's "Book of Lenses"
- GPU optimization list https://gist.github.com/silvesthu/505cf0cbf284bb4b971f6834b8fec93d
- a keyboard shortcut for searching the Type_Info of context to narrow down on an inspect() thing
- david oreilly models collection
- indexing https://www.braynzarsoft.net/viewtutorial/q16390-33-instancing-with-indexed-primitives
- late latch mouse position: https://github.com/nlguillemot/LateLatching/blob/master/main.cpp
- building a debug "bundled" version would mean better stack traces during debugging 
- [gpu shader derivative functions](http://www.aclockworkberry.com/shader-derivative-functions/)
- a version of `__temporary_allocator` that ping pongs between VirtualAlloc guard pages so you know immediately if you're reading junk data
- a bad-guy who's left-right eye perspective is BACKWARDS. it literally makes you sick...
- find out if we can provide the layout of buffers to Renderdoc via some API
- "on change" component for reactive programming, or for GPU uploads
    think about GetWriteWatch(), or using exception guards on virtualalloc pages, to know whether we need to write stuff to the gpu or not...
- [D3D11 Vendor Hacks](https://docs.google.com/spreadsheets/d/1J_HIRVlYK8iI4u6AJrCeb66L5W36UDkd9ExSCku9s_o/edit#gid=0)
- Unreal's "posses and drive any object"
    - smart snapping to the edges of things by holding a key
    - the scene camera follows you around as you drive it
- someone else can walk through the scene while I'm playing it.
    - would it be easy to stream a video texture to another computer? Then the data structure sharing thing doesn't have to come first. just
    - render another camera to a render texture and find a library to stream it...ideally gamedev focused so it provides input, etc.
- multiplayer edit and play simultaneously
    - the fundamental data structure is a shared one
- visual references - [Zach L](https://www.instagram.com/p/CJo8vk4DFkP/?igshid=6euuke12qmrg)
- [game design library](https://nightblade9.github.io/game-design-library/)
- research general "mistakes we made making this engine"
- research network shared data stores. What would the minimum thing be.
- 1 hour chipping away at the [game design curriculum](https://www.riotgames.com/en/urf-academy/curriculum-guide)

## random game design thoughts/ideas
- shmup save points you can use anywhere, but they are a limited resource. going further without using them allows you to level up faster.  a roguelike shmup!
