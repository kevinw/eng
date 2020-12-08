Sorting_Layer :: u8;

SpriteRenderer :: struct {
    using component: Component;

    timer: float64; @noui
    fps: int = 10; // TODO: no
    color := rl.WHITE;

    sprite: []Sprite;
    texture: rl.Texture; @noui  // deprecated

    last_timer: float64; @noui @noserialize
    canary := 42; @noui @noserialize

    sprite_anim: LiveSprite;
    anim_tag: string;

    sorting_layer: Sorting_Layer;
    
    _current_frame: Sprite_Anim.Sprite_Anim.Frame; @noserialize @noui
    _last_frame_index: int; @noserialize @noui // TODO: the underscore breaks wbml
    //right now. we should fix that, regardless of if we want to actually
    //serialize this field or not.

    mode: Mode;

    Mode :: enum u8 {
        Play_Forever      :: 0;
        Play_Once_And_Die :: 1;
    }

    slice_mode: Slice_Mode;

    Slice_Mode :: enum u8 {
        None :: 0;
        NineSlice :: 1;
    }

    border: struct {
        left: s32;
        top: s32;
        right: s32;
        bottom: s32;
    };
}

on_enable :: (using it: *SpriteRenderer, parent_entity: *Entity) {
    parent_entity.flags |= .Has_Component_Rect;
}

get_entity_rect :: (using it: *SpriteRenderer) -> (bool, rl.Rectangle) {
    ok, entity_ptr := get_entity(it.entity);
    if !ok return false, .{};
    transform := get_transform(it);

    default_transform: Transform;
    if !transform
        transform = *default_transform;
        

    if sprite.count > 0 {
        pos := transform.position.xy;
        r, offset, idx := sprite_get_rect(sprite, 0, 0);
        return true, rl.make_Rectangle(pos.x + offset.x, pos.y + offset.y, r.width, r.height);
    }
    if has_value(sprite_anim) {
        r := get_sprite_anim_dest_rect(it, transform);

        ok, _current_frame, index := Sprite_Anim.get_frame(sprite_anim._entry, timer, anim_tag);
        if ok {
            r.position -= Vector2Scale(_current_frame.offset, transform.scale.xy);
        }

        return true, r;
    }


    return false, .{};
}

update :: (using it: *SpriteRenderer) {
    assert(entity.id > 0);
    assert(canary == 42);

    last_timer = timer;
    timer += context.state.Time.delta_time;

    if has_value(sprite_anim) {
        ok: bool;
        index: int = -1;
        ok, _current_frame, index = Sprite_Anim.get_frame(sprite_anim._entry, timer, anim_tag);
        if mode == .Play_Once_And_Die && _last_frame_index > 0 && index == 0  {
            destroy_entity(entity);
        }
        _last_frame_index = index;
    }
}

DEPRECATED_draw_old_sprite :: () {
}

Drawable_Layer :: struct {
    spriterenderers: [..]*SpriteRenderer;
    rectrenderers:   [..]*RectRenderer;
}

draw_all_drawables :: (world: *World) {
    by_layer: [256]Drawable_Layer;

    highest_layer: Sorting_Layer = 0;
    highest_layer = max(highest_layer, queue_all_drawable(*world._SpriteRenderer, by_layer));
    highest_layer = max(highest_layer, queue_all_drawable(*world._RectRenderer, by_layer));

    for l: 0..highest_layer {
        layer := *by_layer[l];
        for layer.rectrenderers
            _draw(it);
        for layer.spriterenderers
            _draw(it, get_transform(it));
    }
}

queue_all_drawable :: (sprites: *Array_With_Holes(SpriteRenderer), by_layer: [256]Drawable_Layer) -> (highest_layer: Sorting_Layer) {
    highest_layer: Sorting_Layer;
    for * sprites {
        array_add(*by_layer[it.sorting_layer].spriterenderers, it);
        highest_layer = max(highest_layer, it.sorting_layer);
    }
    return highest_layer;
}

_draw :: (using it: *SpriteRenderer, transform: *Transform) {
    assert(entity.id > 0);

    default_transform: Transform;
    if transform == null
        transform = *default_transform;
    position := *transform.position;

    // DEPRECATED - this is the old atlas parsing sprite thing. prefer aseprite and 'sprite_anim' now!
    if sprite.count > 0 {
        sprite_rect, offset := sprite_get_rect(sprite, timer, fps);
        dest_rect := rect(position.x + offset.x, position.y + offset.y, sprite_rect.width, sprite_rect.height);
        origin := v2(0, 0);
        // DEPRECATED DO NOT IMPROVE
        // DEPRECATED DO NOT IMPROVE
        rl.DrawTexturePro(texture, sprite_rect, dest_rect, origin, 0, color);
        // DEPRECATED DO NOT IMPROVE
        // DEPRECATED DO NOT IMPROVE
    }


    if has_value(sprite_anim) {
        dest_rect := get_sprite_anim_dest_rect(it, transform);
        if #complete slice_mode == {
            case .None;
                draw_texture(_current_frame.texture, _current_frame.rect, dest_rect, _current_frame.offset, tint=color);
            case .NineSlice;
                npatch_info: rl.NPatchInfo;
                npatch_info.sourceRec = _current_frame.rect;
                npatch_info.left = border.left;
                npatch_info.top = border.top;
                npatch_info.right = border.right;
                npatch_info.bottom = border.bottom;
                npatch_info.type = cast(s32)rl.NPatchType.NPT_9PATCH; // TODO: raylib bindings should make the type of the 'type' field here the enum

                rl.DrawTextureNPatch(_current_frame.texture, npatch_info, dest_rect, Vector2Scale(_current_frame.offset, transform.scale.xy), 0, color);
                
        }
    }
}

get_sprite_anim_dest_rect :: (it: *SpriteRenderer, transform: *Transform) -> rl.Rectangle {
    dest_rect := rl.make_Rectangle(transform.position.x, transform.position.y, it._current_frame.rect.width, it._current_frame.rect.height);
    dest_rect.width  *= transform.scale.x;
    dest_rect.height *= transform.scale.y;
    return dest_rect;
}

draw_debug :: (using it: *SpriteRenderer, transform: *Transform) {
    
    
}

#scope_file
#import "Math";
rl :: #import "raylib";
#import "raymath";
#import "toolbelt";
Sprite_Anim :: #import "Sprite_Anim";
#import "Live_Types";
