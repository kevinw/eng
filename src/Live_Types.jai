Live_Asset_Database :: struct {
    textures: [..]LiveTextureEntry;
    shaders:  [..]LiveShaderEntry;
    sprites:  [..]LiveSpriteEntry;
}

LiveThing :: struct(T: Type) {
    using _entry: *T;

    Empty :: LiveThing(T).{};
}

has_value :: (thing: LiveThing) -> bool {
    return thing._entry != null;
}

LiveTexture :: LiveThing(LiveTextureEntry);
LiveShader  :: LiveThing(LiveShaderEntry);
LiveSprite  :: LiveThing(LiveSpriteEntry);

LiveEntry :: struct {
    count: u16;
}

LiveSpriteEntry :: struct {
    using _live_entry: LiveEntry;
    filename: string;
    using sprite: Sprite_Anim;
}

LiveTextureEntry :: struct {
    using _live_entry: LiveEntry;

    filename: string;
    using resource: rl.Texture;
}

LiveShaderEntry :: struct {
    using live_entry: LiveEntry;

    vs_filename: string;
    fs_filename: string;

    using resource: rl.Shader;
}

#scope_file
rl :: #import "raylib";
#import "Sprite_Anim";
#import "Basic";
