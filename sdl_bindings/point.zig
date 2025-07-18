const C = @import("c.zig").C;
const rect = @import("rect.zig");

pub const Ipoint = extern struct {
    x: i32,
    y: i32,

    /// TODO: Check if self really needs to be a pointer
    pub fn toSDL(self: *Ipoint) *C.SDL_Point {
        return @ptrCast(self);
    }

    /// TODO: Check if self and rectangle really needs to be a pointer
    pub fn inRect(self: *Fpoint, rectangle: *rect.Irect) bool {
        return C.SDL_PointInRect(self.toSDL(), rectangle.toSDL());
    }
};

pub const Fpoint = extern struct {
    x: f32,
    y: f32,

    /// TODO: Check if self really needs to be a pointer
    pub fn toSDL(self: *Fpoint) *C.SDL_FPoint {
        return @ptrCast(self);
    }

    /// TODO: Check if self and rectangle really needs to be a pointer
    pub fn inRect(self: *Fpoint, rectangle: *rect.Frect) bool {
        return C.SDL_PointInRectFloat(self.toSDL(), rectangle.toSDL());
    }
};
