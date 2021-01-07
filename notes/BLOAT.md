# bloat
- all the places where we do assert(condition, tprint("message %", foo))
- we have both lz4 and miniz. let's just use one of them.
- non-editor build
    - no undo
    - no resources/ folder
    - no textual WBML parsing
- from imconfig.h
- imgui.ini - do we need it? can it at least get a different name, and go in a user appdata temp dir somewhere?
```
//---- Avoid multiple STB libraries implementations, or redefine path/filenames to prioritize another version
// By default the embedded implementations are declared static and not available outside of imgui cpp files.
//#define IMGUI_STB_TRUETYPE_FILENAME   "my_folder/stb_truetype.h"
//#define IMGUI_STB_RECT_PACK_FILENAME  "my_folder/stb_rect_pack.h"
//#define IMGUI_DISABLE_STB_TRUETYPE_IMPLEMENTATION
//#define IMGUI_DISABLE_STB_RECT_PACK_IMPLEMENTATION
```
- make sure ROBUSTNESS flags in entity / array with holes are off
- miniz (and probably others) has /z7 embedded debugging info
- find or make a tool to see if there is debugging info anywhere?

## DONE
- the tprints for debug names in wbml serialization and entity stuff get run A
  LOT. maybe we need a "devprint" which is effectively a no-op on release (or
  even most dev?) builds
- link (and other libraries?) raylib statically
- in release mode, bypass plugin architecture and embed game.dll functions directly
- in release mode, make sure debug allocators are off
