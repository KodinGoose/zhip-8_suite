const C = @import("c.zig").C;

pub const Irect = packed struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    /// TODO: Check if self and other has to be a pointer
    pub fn intersectRect(self: *Irect, other: *Irect) bool {
        return C.SDL_HasRectIntersection(self.toSDL(), other.toSDL());
    }

    /// TODO: Check if self has to be a pointer
    pub fn toSDL(self: *Irect) *C.SDL_Rect {
        return @ptrCast(self);
    }

    pub fn toFrect(self: Irect) Frect {
        return .{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
            .w = @floatFromInt(self.w),
            .h = @floatFromInt(self.h),
        };
    }
};

pub const Frect = packed struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    /// TODO: Check if self and other has to be a pointer
    pub fn intersectRect(self: *Frect, other: *Frect) bool {
        return C.SDL_HasRectIntersectionFloat(self.toSDL(), other.toSDL());
    }

    /// TODO: Check if self has to be a pointer
    pub fn toSDL(self: *Frect) *C.SDL_FRect {
        return @ptrCast(self);
    }

    pub fn toIrect(self: Frect) Irect {
        return .{
            .x = @intFromFloat(self.x),
            .y = @intFromFloat(self.y),
            .w = @intFromFloat(self.w),
            .h = @intFromFloat(self.h),
        };
    }
};
