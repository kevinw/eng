# bloat

- the tprints for debug names in wbml serialization and entity stuff get run A
  LOT. maybe we need a "devprint" which is effectively a no-op on release (or
  even most dev?) builds

- from imconfig.h

```
//---- Avoid multiple STB libraries implementations, or redefine path/filenames to prioritize another version
// By default the embedded implementations are declared static and not available outside of imgui cpp files.
//#define IMGUI_STB_TRUETYPE_FILENAME   "my_folder/stb_truetype.h"
//#define IMGUI_STB_RECT_PACK_FILENAME  "my_folder/stb_rect_pack.h"
//#define IMGUI_DISABLE_STB_TRUETYPE_IMPLEMENTATION
//#define IMGUI_DISABLE_STB_RECT_PACK_IMPLEMENTATION
```

- make sure debug allocators are off
- make sure ROBUSTNESS flags in entity / array with holes are off

- link (and other libraries?) raylib statically

- bypass plugin architecture and embed game.dll functions directly
-miniz (and probably others) has /z7 embedded debugging info
- find a tool to see if there is debugging info anywhere?
