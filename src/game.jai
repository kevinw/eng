#import "raylib";

#program_export
update_and_draw :: () {
    {
    }
    {
        BeginDrawing();
        defer EndDrawing();
        ClearBackground(RAYWHITE);

        F :: 150;

        for x_: 0..F {
            x := cast(s32)x_;

            color: Color;
            color.r = cast(u8)(255*cast(float)x/cast(float)F);
            color.g = 128;
            color.b = cast(u8)(255*cast(float)x/cast(float)F);
            color.a = cast(u8)(255*cast(float)x/cast(float)F);

            text_x := cast(float)(x*x)*0.002;
            
            DrawText("Hello, jai", xx text_x, x, x, color);

        }
    }
}