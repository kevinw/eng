# TODO

## Immediate
 
- materials
    - how does TheForge do it?
- fix sprite ordering to just respect Z by default. We can worry about sorting transparent things later
- swapchain/renderer rework - we need one renderer, but two swapchains
- Depth of field
    - Second: visualize intermediate textures easily with a single log call
- GPU mouse picking
- make the multiview projection translation start left and end up right of the camera
- disconnect the scene view and the LKG camera somehow, but keep it easy to preview one in the other...
    - copy frustum visualization code from LKG Unity plugin
    - at runtime, have the LKG camera follow the player
- before things get too elaborate or complicated, try using Matrix4x3 
- color palettes

## High Priority
- [coroutines in C](https://www.chiark.greenend.org.uk/~sgtatham/coroutines.html)
- Join the [Berlin mini-game jam discord](https://discord.gg/evM44ns)
- Make the editor prompt you to save changes to a scene on exit.
- 1 hour chipping away at the [game design curriculum](https://www.riotgames.com/en/urf-academy/curriculum-guide)
- Maybe show the current task in the game as an overlay!
- Figure out how Link should work and make it work!
- ImGui compiler node visualizer (bonus points for using the node editor)
- `on_enable` needs to be called after all sibling components get added. Then I
  can fix `Cam_Follow` to set it's target position on startup.
- automate structs for HLSL packing rules (maybe with a macro usable by other folks)

## Medium Priority
- Watch videos and read blogs about and take notes on Peek, Roblox, and Dreams editing tools
- Don't make an engine. Make a game. Find a way to center that.
- 2 hour timer; procreate doodling
- Try catching windows touch events and make rotation of entities with two fingers work via iPad remote desktop
- research general "mistakes we made making this engine"
- research network shared data stores. What would the minimum thing be.
- In the UI, the color field should have a different background color to
  indicate that the prefab is overridden. As a first attempt at implementing
  this.
- C library job systems
- Temporal anti-aliasing implementation 
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
- Research binary pack formats; C libraries that do virtual file systems
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
- flappy word - flappy bird mechanics, but you're swapping letters in words vertically
    - a column of characters. one or more words may be created from it. you're flapping the bird as you go, trying to fit into the gap that you create by removing a word.


## research ideas:
    - a version of __temporary_allocator that ping pongs between VirtualAlloc guard pages so you know immediately if you're reading junk data
    - a badguy who's left-right eye perspective is BACKWARDS. it literally makes you sick...
    - find out if we can provide the layout of buffers to Renderdoc via some API
    - "on change" component for reactive programming, or for GPU uploads
        think about GetWriteWatch(), or using exception guards on virtualalloc pages, to know whether we need to write stuff to the gpu or not...
    - [D3D11 Vendor Hacks](https://docs.google.com/spreadsheets/d/1J_HIRVlYK8iI4u6AJrCeb66L5W36UDkd9ExSCku9s_o/edit#gid=0)


