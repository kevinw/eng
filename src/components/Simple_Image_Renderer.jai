Simple_Image_Renderer :: struct {
    using component: Component;

    texture: LiveTexture;
    tint: rl.Color = rl.WHITE;
}

on_enable :: (it: *Simple_Image_Renderer, entity: *Entity) {
    entity_handle := get_entity_handle(entity);
    add_or_get_component(entity_handle, Editor_Selectable_Rect);
}

update :: (using it: *Simple_Image_Renderer, transform: *Transform, esr: *Editor_Selectable_Rect) {
    /*

    TODO @Design @Speed
   
    this is starting to go down the path of updating things every frame.
    which, for some values, maybe is ok. but I wonder if there's a better way.
    or several better ways.
    
    for example, this particular code only needs to be run in the editor, in edit mode. so
    maybe there should be an "update_editor" proc.
    
    more generally, having a way to setup a thing where "values depend on other values" would
    be a good thing. you could imagine a component which is in charge of watching this bit of
    memory, and when it changes, running a callback. then those things could be run at different
    frame granularities, sorted, etc...definitely need more research.
    
    I would also love to avoid the pattern in Unity where you often have
      float MyThing; 
      float lastMyThing;
    
      if (MyThing != lastMyThing) {
          DoExpensiveOperation();
          lastMyThing = MyThing;
      }
    */
   

    if has_value(texture)
        esr.rect = rl.make_Rectangle(0, 0, texture.width, texture.height);
    else
        esr.rect = rl.make_Rectangle(0, 0, 0, 0);
}

draw :: (using it: *Simple_Image_Renderer, transform: *Transform) {
    if !has_value(texture)
        return;
    tex := texture.resource;

    source_rect := rl.make_Rectangle(0, 0, tex.width, tex.height);
    dest_rect := rl.make_Rectangle(transform.position.x, transform.position.y, source_rect.width, source_rect.height);
    origin: rl.Vector2;
    rotation := 0.0;

    rl.DrawTexturePro(tex, source_rect, dest_rect, origin, rotation, tint);
}

#scope_file

rl :: #import "raylib";
