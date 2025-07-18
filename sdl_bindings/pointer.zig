const C = @import("c.zig").C;
const point = @import("point.zig");

pub const MouseInfo = struct {
    point: point.Fpoint = undefined,
    left_button_down: bool = false,
    middle_button_down: bool = false,
    right_button_down: bool = false,
    side1_button_down: bool = false,
    side2_button_down: bool = false,
};

pub fn getMouseInfo() MouseInfo {
    var info: MouseInfo = undefined;
    const mask = C.SDL_GetMouseState(&info.point.x, &info.point.y);
    info.left_button_down = if (mask & C.SDL_BUTTON_LMASK == 1) true else false;
    info.middle_button_down = if (mask & C.SDL_BUTTON_MMASK == 1) true else false;
    info.right_button_down = if (mask & C.SDL_BUTTON_RMASK == 1) true else false;
    info.side1_button_down = if (mask & C.SDL_BUTTON_X1 == 1) true else false;
    info.side2_button_down = if (mask & C.SDL_BUTTON_X2 == 1) true else false;
    return info;
}

pub const MouseInfoAdv = struct {
    point: point.Fpoint = undefined,
    left_button_down: bool = false,
    left_button_pressed: bool = false,
    left_button_released: bool = false,
    middle_button_down: bool = false,
    middle_button_pressed: bool = false,
    middle_button_released: bool = false,
    right_button_down: bool = false,
    right_button_pressed: bool = false,
    right_button_released: bool = false,
    side1_button_down: bool = false,
    side1_button_pressed: bool = false,
    side1_button_released: bool = false,
    side2_button_down: bool = false,
    side2_button_pressed: bool = false,
    side2_button_released: bool = false,

    /// Call on button down event
    /// Also updates x and y coordinates
    pub fn buttonDown(self: *MouseInfoAdv) void {
        const info = getMouseInfo();
        self.point = info.point;
        if (info.left_button_down) {
            self.left_button_released = false;
            self.left_button_pressed = if (self.left_button_down) false else true;
            self.left_button_down = true;
        }
        if (info.middle_button_down) {
            self.middle_button_released = false;
            self.middle_button_pressed = if (self.middle_button_down) false else true;
            self.middle_button_down = true;
        }
        if (info.right_button_down) {
            self.right_button_released = false;
            self.right_button_pressed = if (self.right_button_down) false else true;
            self.right_button_down = true;
        }
        if (info.side1_button_down) {
            self.side1_button_released = false;
            self.side1_button_pressed = if (self.side1_button_down) false else true;
            self.side1_button_down = true;
        }
        if (info.side2_button_down) {
            self.side2_button_released = false;
            self.side2_button_pressed = if (self.side2_button_down) false else true;
            self.side2_button_down = true;
        }
    }

    /// Call on button up event
    /// Also updates x and y coordinates
    pub fn buttonUp(self: *MouseInfoAdv) void {
        const info = getMouseInfo();
        self.point = info.point;
        if (!info.left_button_down) {
            self.left_button_pressed = false;
            self.left_button_released = if (!self.left_button_down) false else true;
            self.left_button_down = false;
        }
        if (!info.middle_button_down) {
            self.middle_button_pressed = false;
            self.middle_button_released = if (!self.middle_button_down) false else true;
            self.middle_button_down = false;
        }
        if (!info.right_button_down) {
            self.right_button_pressed = false;
            self.right_button_released = if (!self.right_button_down) false else true;
            self.right_button_down = false;
        }
        if (!info.side1_button_down) {
            self.side1_button_pressed = false;
            self.side1_button_released = if (!self.side1_button_down) false else true;
            self.side1_button_down = false;
        }
        if (!info.side2_button_down) {
            self.side2_button_pressed = false;
            self.side2_button_released = if (!self.side2_button_down) false else true;
            self.side2_button_down = false;
        }
    }

    /// Call this function right before event loop
    pub fn reset(self: *MouseInfoAdv) void {
        self.left_button_pressed = false;
        self.left_button_released = false;
        self.middle_button_pressed = false;
        self.middle_button_released = false;
        self.right_button_pressed = false;
        self.right_button_released = false;
        self.side1_button_pressed = false;
        self.side1_button_released = false;
        self.side2_button_pressed = false;
        self.side2_button_released = false;
    }

    /// Only updated x and y coordinates
    pub fn mouseMoved(self: *MouseInfoAdv) void {
        const info = getMouseInfo();
        self.point = info.point;
    }
};
