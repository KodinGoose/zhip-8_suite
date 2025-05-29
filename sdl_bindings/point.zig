const C = @import("c.zig").C;

pub const Ipoint = extern struct {
    x: i32,
    y: i32,

    pub fn toSDL(self: *Ipoint) *C.SDL_Point {
        return @ptrCast(self);
    }
};

pub const Fpoint = extern struct {
    x: f32,
    y: f32,

    pub fn toSDL(self: *Fpoint) *C.SDL_FPoint {
        return @ptrCast(self);
    }
};
