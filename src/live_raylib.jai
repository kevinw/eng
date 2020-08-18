HOTLOADING_ENABLED :: true;

#if HOTLOADING_ENABLED
    #import "Hotloader";

LiveTexture :: struct { using _entry: *LiveTextureEntry; }
LiveShader  :: struct { using _entry: *LiveShaderEntry; }


LiveTextureEntry :: struct {
    count: u16;
    filename: string;
    using resource: Texture;
}

LiveShaderEntry :: struct {
    count: u16;
    vs_filename: string;
    fs_filename: string;
    using resource: Shader;
}

set_shader_val :: (shader: LiveShader, name: string, val: $T) {
    set_shader_val(shader.resource, name, val);
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


_to_temp_c_string :: (s: string) -> *u8 {
    if s.count == 0 return null;
    result : *u8 = talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
}

constant_or_temp_cstring :: inline ($$text: string) -> *u8 {
    c_str: *u8;
    #if is_constant(text) {
        if text.data.count > 0 {
            return text.data;
        }
    }

    return _to_temp_c_string(text);
}
