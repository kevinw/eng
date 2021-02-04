/*

the goal is to be able to only use assimp in the asset pipeline tool. it doesn't ship with games

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
    debug_name: string; @owned
}

Sub_Mesh :: struct {
    material: LiveMaterial;
    vertices: Buffer;
    indices:  Buffer;
}

unload_mesh :: (mesh: *Mesh) {
    // TODO
}

Loader :: struct {
    current_filename: string;
}

Vertex :: struct {
    pos:      Vector3;
    texcoord: Vector2;
    color:    Vector4 = .{1, 1, 1, 1};

    instance_id: u32;
    entity_id: u32;
    entity_generation: s32;
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
        print("load_mesh error: %\n", get_ai_error_string());
        return false;
    }
    defer ai.ReleaseImport(scene);

    loader: Loader;
    loader.current_filename = filename;

    process_node(*loader, mesh, scene.mRootNode, scene);
    process_materials(*loader, scene, filename);
    mesh.debug_name = sprint("Mesh from %", filename);

    return true;

}

#scope_file

get_ai_error_string :: () -> string {
    ai_err := ai.GetErrorString();
    if ai_err != null return to_string(cast(*u8)ai_err);
    return "";
}
 

to_string :: (ai_str: ai.String) -> string {
    s: string;
    s.count = ai_str.length;
    s.data = cast(*u8)ai_str.data.data;
    return s;
}

process_materials :: (using loader: *Loader, scene: *ai.Scene, filename: string) {
    for material_idx: 0..cast,trunc(int)scene.mNumMaterials - 1 {
        ai_mat := scene.mMaterials[material_idx];

        //path: ai.String;
        //ai.GetMaterialString(ai_mat, AI_MATKEY_TEXTURE_DIFFUSE(0), &albedoPath);

        print("material %:\n", material_idx);
        for prop_idx: 0..cast,trunc(int)ai_mat.mNumProperties - 1 {
            using prop := ai_mat.mProperties[prop_idx];
            assert(prop != null);
            print("  prop %: (key=%, semantic=%, index=%, type=%, data_length: %)\n", prop_idx, to_string(mKey), mSemantic, mIndex, mType, mDataLength);

            print_val_array :: ($T: Type, mData: *s8, mDataLength: u32) {
                arr: []T;
                arr.data = cast(*T)mData;
                arr.count = mDataLength / size_of(T);
                print("    % value(s): ", T);
                for arr print("% ", it);
                print("\n");
                //val := cast(*s32)mData;
            }

            if mType == {
                case .aiPTI_String;
                    out_string := cast(*ai.String)mData;
                    print("    string value: '%'\n", to_string(<<out_string));
                case .aiPTI_Integer;
                    print_val_array(s32, mData, mDataLength);
                case .aiPTI_Float;
                    print_val_array(float32, mData, mDataLength);

                    
            }

        }
    }
}


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

    for 0..cast,trunc(int)aiMesh.mNumVertices - 1 {
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
    defer array_free(indices);

    for 0..cast,trunc(int)aiMesh.mNumFaces - 1 {
        face := aiMesh.mFaces[it];
        for j: 0..face.mNumIndices - 1
            array_add(*indices, face.mIndices[j]);
    }

    submesh.indices = create_immutable_buffer(indices, .Index, "indices for submesh in %", loader.current_filename);
    
    submesh.material = get_material("pbr");
}

process_node :: (using loader: *Loader, mesh: *Mesh, node: *ai.Node, scene: *ai.Scene) {
    for 0..cast,trunc(int)node.mNumMeshes - 1 {
        aiMesh := scene.mMeshes[node.mMeshes[it]];
        submesh := array_add(*mesh.sub_meshes);
        process_sub_mesh(loader, submesh, aiMesh, scene);
    }

	for 0..cast,trunc(int)node.mNumChildren - 1
		process_node(loader, mesh, node.mChildren[it], scene);
}

ai :: #import "assimp";
#import "live_raylib";
#import "renderer";
#import "Basic";
#import "Live_Types";
#import "Math";

