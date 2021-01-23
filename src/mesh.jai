/*
1. simple mesh load and render (using assimp opengl tutorial)
2. spawning many Component copies means we use a single instanced draw
3. question: can many different meshes go into one buffer and then instance
   rendering pick different offets and sizes? like bindless I guess. or similar
   to a spritebatch, but for meshes.
4. let's start with a simple pointer to a Material struct with hardcoded PBR
   like functionality. hopefully the material "system" can wait, since that's a
   whole other thing to make design decisions about.
--
5. regarding (3), how does compute skinning relate to all that? can EVERYTHING
   just be a GPU driven draw call?
--

99. research question: does there exist a possible setup where instead of
blasting the entire game state down the bus every frame from CPU->GPU we
instead track changes and send the delta as an encoding? spend some gpu cycles
decoding them and applying the changes locally to gpu memory, but saving enough
bus bandwidth that it's still worthwhile?

*/

Mesh :: struct {
    sub_meshes: [..]Sub_Mesh;
}

Sub_Mesh :: struct {
    material: *Material;
}

Material :: struct {
}

unload_mesh :: (mesh: *Mesh) {
    // TODO
}

load_mesh :: (mesh: *Mesh, filename: string) -> bool {
    unload_mesh(mesh);

    scene := ai.ImportFile(cast(*s8)tprint("%\0", filename).data,
        cast(u32)(ai.PostProcessSteps.CalcTangentSpace
        | .Triangulate
        | .JoinIdenticalVertices
        | .SortByPType));

    if !scene {
        print("load_mesh error: %\n", ai.GetErrorString());
        return false;
    }

    defer ai.ReleaseImport(scene);

    //DoTheSceneProcessing( scene);

    // We're done. Release all resources associated with this import
    return true;

}

#scope_file
ai :: #import "assimp";
#import "Basic";
