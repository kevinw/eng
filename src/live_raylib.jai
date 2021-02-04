#import "Live_Types";

get_asset_name :: (filename: string) -> string {
    if filename.count == 0 return "";
    return String.path_strip_extension(String.path_filename(filename));
}


try_reload_live_resource :: (full_name_stripped: string, extension: string) {
    did_reload := false;
    if extension == {
        case "png"; #through;
        case "jpg"; #through;
        case "jpeg";
            did_reload = TryReloadLiveTexturePath(full_name_stripped);
        case "hlsl";
            // TODO: this is a hack until we have multiple swapchains, not multiple renderers
            for r: context.state.all_renderers
                did_reload = reload_shaders_with_filename(full_name_stripped);
        case "aseprite"; #through;
        case "ase";
            did_reload = TryReloadLiveSprite(full_name_stripped);
        case;
            // do nothing
    }

    if did_reload
        logprint("live", "reloaded asset %", full_name_stripped);
}


get_path_for_asset :: (sprite_anim: *Sprite_Anim) -> string {
    using context.state;

    for * live.sprites
        if *it.sprite == sprite_anim
            return it.filename;

    return "";
}


LoadLiveTexture :: (filename: string, texture: Texture) -> LiveTexture {
    // create a new live entry for a texture loaded elsewhere (through aseprite for example)

    new_entry := array_add(*context.state.live.textures);
    new_entry.filename = copy_string(filename);
    new_entry.resource = texture;
    new_entry.count = 1;

    obj: LiveTexture;
    obj._entry = new_entry;
    return obj;
}

add_material :: (name: string, $shader_filename: string) {
    new_entry := array_add(*context.state.live.materials);

    new_entry.name = copy_string(name);
    ok := load_shader_from_file(*new_entry.shader, shader_filename);
    assert(ok);

    new_entry.pipeline = make_pipeline(*new_entry.shader, .Triangles,
        cull_mode = .None,
        blend_mode = .Default,
        depth_stencil_opts = .{
            depth_write = true,
            depth_compare_func = .Less,
        },
        label = "mesh draw pipeline");

}

get_material :: (name: string) -> LiveMaterial {
    for * context.state.live.materials {
        if it.name == name {
            mat: LiveMaterial;
            mat._entry = it;
            return mat;
        }
    }

    assert(false, "could not find material %", name);
    return .{};
}

LoadLiveSprite :: (filename: string) -> (sprite: LiveSprite, was_new: bool) {
    assert(filename.count > 0);
    obj: LiveSprite;
    was_new := false;

    for * context.state.live.sprites {
        if it.filename == filename {
            obj._entry = it;
            break;
        }
    }

    if obj._entry == null {
        was_new = true;
        new_entry := array_add(*context.state.live.sprites);
        new_entry.filename = copy_string(filename);
        ok := load_from_aseprite(*new_entry.sprite, filename);
        assert(ok, "error loading '%'", filename);
        obj._entry = new_entry;
    }

    obj._entry.count += 1;
    return obj, was_new;
}

LoadLiveTexture :: (filename: string) -> LiveTexture {
    assert(filename.count > 0);
    using context.state;

    obj: LiveTexture;
    for * context.state.live.textures {
        if it.filename == filename {
            obj._entry = it;
            break;
        }
    }

    if obj._entry == null {
        old_pointer := context.state.live.textures.data;
        new_entry := array_add(*context.state.live.textures);
        assert(old_pointer == null || context.state.live.textures.data == old_pointer, "moved!?");
        new_entry.filename = copy_string(filename);

        tex_ok: bool;
        tex_ok, new_entry.resource = load_texture_from_file(filename);
        assert(tex_ok);

        obj._entry = new_entry;
    }

    obj._entry.count += 1;
    return obj;
}

DrawTexture :: (texture: *LiveTexture, posX: s32, posY: s32, tint: rl.Color) {
    rl.DrawTexture(*texture._entry.resource, posX, posY, tint);
}

DrawTexturePro :: (texture: *LiveTexture, src_rect: rl.Rectangle, dest_rect: rl.Rectangle, offset: Vector2 = .{0, 0}, rotation:float = 0, color := rl.WHITE) {
    rl.DrawTexturePro(*texture._entry.resource, src_rect, dest_rect, offset, rotation, color);
}

DrawTexturePro :: (texture: *LiveTexture, src_rect: rl.Rectangle, dest_rect: rl.Rectangle, offset: Vector2 = .{0, 0}, rotation:float = 0, color := Vector4.{1, 1, 1, 1}) {
    rl.DrawTexturePro(*texture._entry.resource, src_rect, dest_rect, offset, rotation, color);
}

TryReloadLiveTexturePath :: (filename: string) -> bool {
    found := false;

    for * context.state.live.textures {
        if it.filename == filename {
            print("TODO: implement unload texture!\n");
            tex_ok: bool;
            tex_ok, it.resource = load_texture_from_file(it.filename);
            assert(tex_ok);
            found = true;
        }
    }

    return found;
}

TryReloadLiveSprite :: (filename: string) -> bool {
    found := false;
    for * context.state.live.sprites {
        if it.filename != filename continue;

        new_sprite: Sprite_Anim;
        ok := load_from_aseprite(*new_sprite, it.filename);
        if !ok {
            logprint("live", "error reloading sprite '%'", filename);
            continue;
        }

        deinit(*it.sprite);
        it.sprite = new_sprite;
        found = true;
    }
    return found;
}


#scope_file
#import "toolbelt";
#import "Math";
String :: #import "String";
rl :: #import "raylib";
#import "Basic";
#import "Sprite_Anim";
#import "renderer";
