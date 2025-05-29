const C = @import("c.zig").C;

const InitFlags = packed struct {
    pad_1: u4 = 0,
    /// Implies initialization ov events subsystem
    audio: bool = false,
    /// Implies initialization ov events subsystem
    /// Should be initialized on the main thread
    video: bool = false,
    pad_2: u3 = 0,
    /// Implies initialization ov events subsystem
    /// Should be initialized on the same thread as the video subsystem on Windows if you don't set SDL_HINT_JOYSTICK_THREAD
    joystick: bool = false,
    pad_3: u2 = 0,
    haptic: bool = false,
    /// Implies initialization ov joystick subsystem
    gamepad: bool = false,
    events: bool = false,
    /// Implies initialization ov events subsystem
    sensor: bool = false,
    /// Implies initialization ov events subsystem
    camera: bool = false,
    pad_4: u15 = 0,

    pub fn toSDL(self: InitFlags) C.SDL_InitFlags {
        return @bitCast(self);
    }
};

pub fn initSDL(flags: InitFlags) !void {
    if (!C.SDL_Init(flags.toSDL())) return error.SDLInitFailed;
}

pub fn deinitSDL() void {
    C.SDL_Quit();
}

pub fn initSDL_ttf() !void {
    if (!C.TTF_Init()) return error.SDL_TTFInitFailed;
}

pub fn deinitSDL_ttf() void {
    C.TTF_Quit();
}
