/*

## idea from discord

create same sized/format cpu texture, when you want to copy data from gpu then
call copyresource from gpu texture to this cpu texture and signal fence
(id3d11fence), then in on your cpu side periodically check fence value, once it
is signaled, you can map cpu texture to pointer read/use data, and unmap it but
that'll work only on win10, as fences were added to d3d11 version on win10
before win10 you need to use id3d11query with D3D11_QUERY_EVENT to monitor when
copyresource finishes

## Options from https://ourmachinery.com/post/borderland-part-2-picking/

* Store object ids to framebuffer either in an extra rendering step and read back
to CPU on next frame. Map id to object. The same id buffer can be used to draw
object outlines too (CryEngine)

Use object bounding boxes to only draw objects whose BB intersects the mouse to
world ray. Make a small frustrum around the mouse, and a one-pixel render
target. Draw intersecting objects twice: Once for depth pre-pass, second with
occlusion queries and depth test equal. Object whose query succeeds is
selected. You can implement an x-ray select-all-objects style selection by
skipping the depth pre-pass and simply getting all objects whose query succeeds
(Blender)

*/

Picking_Buffer :: struct {
    depth: float;
    identity: u64;
}

update_picking_buffer :: () {
}

#scope_file
#import "Basic";
