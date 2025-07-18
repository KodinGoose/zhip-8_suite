//! These bindings require SDL_ttf v3.2.0 or newer

const std = @import("std");
const C = @import("c.zig").C;
const render = @import("render.zig");

pub const Font = struct {
    sdl: *C.TTF_Font,

    pub fn load(file_name: [*:0]const u8, point_size: f32) !@This() {
        const ret = C.TTF_OpenFont(file_name, point_size);
        if (ret == null) return error.CouldntLoadFont;
        return Font{ .sdl = ret.? };
    }

    pub fn deinit(self: @This()) void {
        C.TTF_CloseFont(self.sdl);
    }

    const TextRenderType = enum(u8) {
        BLENDED,
        LCD,
        SHADED,
        SOLID,
    };

    /// background_color is ignored if render_type == .Blender or render_type == .Solid
    /// It's safe to just pass in undefined, the compiler will optimize it away
    pub fn renderText(
        self: @This(),
        text: [:0]const u8,
        foreground_color: C.SDL_Color,
        background_color: C.SDL_Color,
        render_type: TextRenderType,
        wrapped: bool,
    ) !*render.Surface {
        var ret: [*c]C.SDL_Surface = undefined;
        switch (render_type) {
            .BLENDED => {
                ret = if (wrapped)
                    C.TTF_RenderText_Blended_Wrapped(self.sdl, text.ptr, text.len, foreground_color, 0)
                else
                    C.TTF_RenderText_Blended(self.sdl, text.ptr, text.len, foreground_color);
            },
            .LCD => {
                ret = if (wrapped)
                    C.TTF_RenderText_LCD_Wrapped(self.sdl, text.ptr, text.len, foreground_color, background_color, 0)
                else
                    C.TTF_RenderText_LCD(self.sdl, text.ptr, text.len, foreground_color, background_color);
            },
            .SHADED => {
                ret = if (wrapped)
                    C.TTF_RenderText_Shaded_Wrapped(self.sdl, text.ptr, text.len, foreground_color, background_color, 0)
                else
                    C.TTF_RenderText_Shaded(self.sdl, text.ptr, text.len, foreground_color, background_color);
            },
            .SOLID => {
                ret = if (wrapped)
                    C.TTF_RenderText_Solid_Wrapped(self.sdl, text.ptr, text.len, foreground_color, 0)
                else
                    C.TTF_RenderText_Solid(self.sdl, text.ptr, text.len, foreground_color);
            },
        }
        if (ret == null) return error.CouldnRenderText;
        return @ptrCast(ret);
    }

    pub fn textSize(self: @This(), text: [:0]const u8) !struct { w: i32, h: i32 } {
        var w: i32 = 2;
        var h: i32 = 2;
        if (!C.TTF_GetStringSize(self.sdl, text.ptr, text.len, &w, &h)) return error.CouldntGetTextSize;
        return .{ .w = w, .h = h };
    }
};
