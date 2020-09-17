#scope_file

inp :: #import "inp";
#import "raymath";

#scope_module

Pong_Paddle :: struct {
    using component: Component;

}

on_enable :: (it: *Pong_Paddle, entity: *Entity) {
}

update :: (it: *Pong_Paddle, transform: *Transform, sprite_renderer: *SpriteRenderer) {
    using context.state;

    m := inp.movement();
    m.y = 0;
    transform.position.xy += m * Time.delta_time * 600;
}
