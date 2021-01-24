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

Loader :: struct {
    current_filename: string;
}

Vertex :: struct {
    pos: Vector3;
    texcoord: Vector2;
}

load_mesh :: (mesh: *Mesh, filename: string) -> bool {
    assert(mesh != null);
    unload_mesh(mesh);

    load_flags := ai.PostProcessSteps.CalcTangentSpace
        | .Triangulate
        | .MakeLeftHanded
        | .JoinIdenticalVertices
        | .SortByPType;

    scene := ai.ImportFile(cast(*s8)tprint("%\0", filename).data, cast(u32)load_flags);
    if !scene {
        print("load_mesh error: %\n", ai.GetErrorString());
        return false;
    }
    defer ai.ReleaseImport(scene);

    loader: Loader;
    loader.current_filename = filename;
    process_node(*loader, mesh, scene.mRootNode, scene);
    mesh.debug_name = sprint("Mesh from %", filename);
    return true;

}
 
#scope_file

process_sub_mesh :: (using loader: *Loader, submesh: *Sub_Mesh, aiMesh: *ai.Mesh, scene: *ai.Scene) {
    assert(submesh != null);

    textures: [..]Texture;

    if aiMesh.mMaterialIndex >= 0 {
        mat := scene.mMaterials[aiMesh.mMaterialIndex];
        /*
		if (textype.empty()) {
            textype = determineTextureType(scene, mat);
        }
        */
    }

    // walk through each of the mesh's vertices
    verts: [..]Vertex;
    defer array_free(verts);

    for 0..cast(int)aiMesh.mNumVertices - 1 {
        vertex := array_add(*verts);
        vertex.pos = aiMesh.mVertices[it];
        if aiMesh.mTextureCoords[0] != null {
            vertex.texcoord.x = aiMesh.mTextureCoords[0][it].x;
            vertex.texcoord.y = aiMesh.mTextureCoords[0][it].y;
        }
    }

    submesh.vertices = create_immutable_buffer(verts, .Vertex, "vertices for submesh in %", loader.current_filename);

    // indices/faces
    indices: [..]Hardcoded_Index_Type;

    for 0..cast(int)aiMesh.mNumFaces - 1 {
        face := aiMesh.mFaces[it];
        for j: 0..face.mNumIndices - 1
            array_add(*indices, face.mIndices[j]);
    }

    submesh.indices = create_immutable_buffer(indices, .Index, "indices for submesh in %", loader.current_filename);
}

process_node :: (using loader: *Loader, mesh: *Mesh, node: *ai.Node, scene: *ai.Scene) {
    for 0..cast(int)node.mNumMeshes - 1 {
        aiMesh := scene.mMeshes[node.mMeshes[it]];
        submesh := array_add(*mesh.sub_meshes);
        process_sub_mesh(loader, submesh, aiMesh, scene);
    }

	for 0..cast(int)node.mNumChildren - 1
		process_node(loader, mesh, node.mChildren[it], scene);
}

Texture :: struct {} // TODO
ai :: #import "assimp";
#import "renderer";
#import "Basic";
#import "Math";

