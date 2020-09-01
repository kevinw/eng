HOTLOADING_ENABLED :: true;

#if HOTLOADING_ENABLED
    #import "Hotloader";

#import "toolbelt";

LiveTexture :: struct { using _entry: *LiveTextureEntry; }
LiveShader  :: struct { using _entry: *LiveShaderEntry; }
LiveSprite  :: struct { using _entry: *LiveSpriteEntry; }

try_reload_live_resource :: (full_name_stripped: string, extension: string) {
    did_reload := false;
    if extension == {
        case "png"; #through;
        case "jpg"; #through;
        case "jpeg";
            did_reload = TryReloadLiveTexturePath(full_name_stripped);
        case "fs"; #through;
        case "vs";
            did_reload = TryReloadLiveShaderPath(full_name_stripped);
        case "aseprite"; #through;
        case "ase";
            did_reload = TryReloadLiveSprite(full_name_stripped);
        case;
            // do nothing
    }

    if did_reload
        logprint("live", "reloaded %", full_name_stripped);
}

LiveEntry :: struct {
    count: u16;
}

LiveSpriteEntry :: struct {
    using _live_entry: LiveEntry;
    filename: string;
    using sprite: SpriteAnim;
}

LiveTextureEntry :: struct {
    using _live_entry: LiveEntry;

    filename: string;
    using resource: Texture;
}

LiveShaderEntry :: struct {
    using live_entry: LiveEntry;

    vs_filename: string;
    fs_filename: string;

    using resource: Shader;
}

set_shader_val :: (shader: LiveShader, name: string, val: $T) {
    set_shader_val(shader.resource, name, val);
}

LoadLiveTexture :: (filename: string, raylib_texture: Texture) -> LiveTexture {
    // create a new live entry for a texture loaded elsewhere (through aseprite for example)

    new_entry := array_add(*state.live.textures);
    new_entry.filename = copy_string(filename);
    new_entry.resource = raylib_texture;
    new_entry.count = 1;

    obj: LiveTexture;
    obj._entry = new_entry;
    return obj;
}

LoadLiveSprite :: (filename: string) -> LiveSprite {
    assert(filename.count > 0);

    obj: LiveSprite;

    for * state.live.sprites {
        if it.filename == filename {
            obj._entry = it;
            break;
        }
    }

    if obj._entry == null {
        new_entry := array_add(*state.live.sprites);
        new_entry.filename = copy_string(filename);
        ok := load_from_aseprite(*new_entry.sprite, filename);
        assert(ok);
        obj._entry = new_entry;
    }

    obj._entry.count += 1;
    return obj;
}

LoadLiveTexture :: (filename: string) -> LiveTexture {
    assert(filename.count > 0);
    using state;

    obj: LiveTexture;
    for * state.live.textures {
        if it.filename == filename {
            obj._entry = it;
            break;
        }
    }

    if obj._entry == null {
        old_pointer := state.live.textures.data;
        new_entry := array_add(*state.live.textures);
        assert(old_pointer == null || state.live.textures.data == old_pointer, "moved!?");
        new_entry.filename = copy_string(filename);
        new_entry.resource = LoadTexture(constant_or_temp_cstring(filename));
        obj._entry = new_entry;
    }

    obj._entry.count += 1;
    return obj;
}


LoadLiveShader  :: (vs_filename: string, fs_filename: string) -> LiveShader  {
    using state;

    obj: LiveShader;
    for * state.live.shaders {
        if it.vs_filename == vs_filename && it.fs_filename == fs_filename {
            obj._entry = it;
            break;
        }
    }

    if obj._entry == null {
        old_pointer := state.live.shaders.data;
        new_entry := array_add(*state.live.shaders);
        assert(old_pointer == null || state.live.shaders.data == old_pointer, "moved!?");
        new_entry.vs_filename = copy_string(vs_filename);
        new_entry.fs_filename = copy_string(fs_filename);

        vs_filenamez: *u8 = ifx new_entry.vs_filename.count > 0 then constant_or_temp_cstring(new_entry.vs_filename) else null;
        fs_filenamez: *u8 = ifx new_entry.fs_filename.count > 0 then constant_or_temp_cstring(new_entry.fs_filename) else null;

        new_entry.resource = LoadShader(vs_filenamez, fs_filenamez);
        obj._entry = new_entry;
    }

    obj._entry.count += 1;
    return obj;
}

DrawTexture :: (texture: LiveTexture, posX: s32, posY: s32, tint: Color) {
    DrawTexture(texture._entry.resource, posX, posY, tint);
}

DrawTexturePro :: (texture: LiveTexture, src_rect: Rectangle, dest_rect: Rectangle, offset: Vector2 = .{0, 0}, rotation:float = 0, color := WHITE) {
    DrawTexturePro(texture._entry.resource, src_rect, dest_rect, offset, rotation, color);
}

UnloadTexture :: (texture: LiveTexture) {
    texture._entry.count -= 1;
    if texture._entry.count == 0 {
        UnloadTexture(texture._entry.resource);
        free(texture._entry.filename);
        for * state.live.textures
            if texture._entry == it
                remove it;
    }
}

TryReloadLiveShaderPath :: (filename: string) -> bool {
    found := false;

    for * state.live.shaders {
        if it.vs_filename == filename || it.fs_filename == filename {
            UnloadShader(it.resource);
            it.resource = LoadShader(
                _to_temp_c_string(it.vs_filename),
                _to_temp_c_string(it.fs_filename),
            );
            found = true;
        }
    }

    return found;
}

TryReloadLiveTexturePath :: (filename: string) -> bool {
    found := false;

    for * state.live.textures {
        if it.filename == filename {
            UnloadTexture(it.resource);
            it.resource = LoadTexture(_to_temp_c_string(it.filename));
            found = true;
        }
    }

    return found;
}

TryReloadLiveSprite :: (filename: string) -> bool {
    found := false;
    for * state.live.sprites {
        if it.filename != filename continue;

        new_sprite: SpriteAnim;
        ok := load_from_aseprite(*new_sprite, it.filename);
        if ok {
            deinit(*it.sprite);
            it.sprite = new_sprite;
            found = true;
        } else {
            logprint("live", "error reloading sprite '%'", filename);
        }
    }
    return found;
}

_to_temp_c_string :: (s: string) -> *u8 {
    if s.count == 0 return null;
    result : *u8 = talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
}
