Live_Asset_Database :: struct {
    textures:  [..]LiveTextureEntry;
    sprites:   [..]LiveSpriteEntry;
    materials: [..]LiveMaterialEntry;
}

LiveThing :: struct(T: Type, CANARY: int) {
    using _entry: *T; @noui @noserialize

    CANARY_TYPE_VALUE :: CANARY;
    canary := CANARY;
}

has_value :: (thing: LiveThing) -> bool {
    return thing._entry != null;
}

LiveTexture   :: LiveThing(LiveTextureEntry, 42);
LiveSprite    :: LiveThing(LiveSpriteEntry, 999);
LiveMaterial  :: LiveThing(LiveMaterialEntry, 2021);

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
    using resource: Texture;
}

LiveMaterialEntry :: struct {
    using _live_entry: LiveEntry;
    name: string;
    pipeline: Pipeline;
    shader: Shader;
}

#scope_file
rl :: #import "raylib";
#import "renderer";
#import "Sprite_Anim";
#import "Basic";
