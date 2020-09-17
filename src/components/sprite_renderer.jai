#scope_file
toolbelt :: #import "toolbelt";
#scope_export

SpriteRenderer :: struct {
    using component: Component;

    timer: float64;
    fps: int = 10; // TODO: no
    color := WHITE;

    sprite: []Sprite;
    texture: Texture;

    last_timer: float64; @noui @noserialize
    canary := 42; @noui

    sprite_anim: LiveSprite;
    anim_tag: string;
    
    _current_frame: Sprite_Anim.Sprite_Anim.Frame; @noserialize
    _last_frame_index: int;

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

get_entity_rect :: (using it: *SpriteRenderer) -> (bool, Rectangle) {
    if sprite.count > 0 {
        ok, entity := get_entity(it.entity);
        if ok {
            pos := entity.transform.position.xy;
            r, offset, idx := sprite_get_rect(sprite, 0, 0);
            return true, make_Rectangle(pos.x + offset.x, pos.y + offset.y, r.width, r.height);
        }
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

draw :: (using it: *SpriteRenderer, transform: *Transform) {
    assert(entity.id > 0);
    position := *transform.position;

    // DEPRECATED - this is the old atlas parsing sprite thing. prefer aseprite and 'sprite_anim' now!
    if sprite.count > 0 {
        sprite_rect, offset := sprite_get_rect(sprite, timer, fps);
        dest_rect := rect(position.x + offset.x, position.y + offset.y, sprite_rect.width, sprite_rect.height);
        origin := v2(0, 0);
        // DEPRECATED DO NOT IMPROVE
        // DEPRECATED DO NOT IMPROVE
        DrawTexturePro(texture, sprite_rect, dest_rect, origin, 0, color);
        // DEPRECATED DO NOT IMPROVE
        // DEPRECATED DO NOT IMPROVE
    }


    if has_value(sprite_anim) {
        pos := position.xy;
        dest_rect := make_Rectangle(pos.x, pos.y, _current_frame.rect.width, _current_frame.rect.height);
        dest_rect.width *= transform.scale.x;
        dest_rect.height *= transform.scale.y;
        if #complete slice_mode == {
            case .None;
                toolbelt.draw_texture(_current_frame.texture, _current_frame.rect, dest_rect, _current_frame.offset);
            case .NineSlice;
                npatch_info: NPatchInfo;
                npatch_info.sourceRec = _current_frame.rect;
                npatch_info.left = border.left;
                npatch_info.top = border.top;
                npatch_info.right = border.right;
                npatch_info.bottom = border.bottom;
                npatch_info.type = cast(s32)NPatchType.NPT_9PATCH; // TODO: raylib bindings should make the type of the 'type' field here the enum

                DrawTextureNPatch(_current_frame.texture, npatch_info, dest_rect, _current_frame.offset, 0, color);
                
        }
    }
}

draw_debug :: (using it: *SpriteRenderer, transform: *Transform) {
    
    
}

#scope_file
#import "raylib";
#import "toolbelt";
Sprite_Anim :: #import "Sprite_Anim";
#import "Live_Types";
