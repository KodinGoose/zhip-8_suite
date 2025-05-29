const std = @import("std");
const builtin = @import("builtin");
var debug_allocator = if (builtin.mode == .Debug) std.heap.DebugAllocator(.{}).init else null;
const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;
const sdl = @import("sdl_bindings");
const Inputs = @import("input").Inputs;
const ObjectsTypes = @import("objects.zig");

/// Whenever an object is added it must be also added to the init, deinit and draw functions
const Objects = struct {
    test_button: ObjectsTypes.Button,

    pub fn init(renderer: sdl.render.Renderer) !@This() {
        return .{
            .test_button = try ObjectsTypes.Button.init(
                renderer,
                "test",
                .{ .r = 0, .g = 0, .b = 0, .a = 255 },
                .{ .r = 200, .g = 200, .b = 200, .a = 255 },
                200,
                200,
                75,
                40,
                16,
            ),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.test_button.deinit();
    }

    pub fn draw(self: *@This(), renderer: sdl.render.Renderer) !void {
        try self.test_button.draw(renderer);
    }
};

var exit = false;
/// True at first so that the user doesn't just get a transparent window
var update_screen = true;
var reset_sprites = false;
var scale: f32 = 1.0;
var window: sdl.render.Window = undefined;

const window_start_width: i32 = 500;
const window_start_height: i32 = 500;

pub fn main() !void {
    try sdl.init.initSDL(.{ .video = true, .events = true });
    defer sdl.init.deinitSDL();

    try sdl.init.initSDL_ttf();
    defer sdl.init.deinitSDL_ttf();

    window = try sdl.render.Window.init(
        "chip-8 suite",
        window_start_width,
        window_start_height,
        .{ .resizable = true },
    );
    defer window.deinit();

    var renderer = try sdl.render.Renderer.init(window);
    defer renderer.deinit();

    var inputs = try Inputs.init(allocator, 1);
    defer inputs.deinit(allocator);

    var objects = try Objects.init(renderer);
    defer objects.deinit();

    while (!exit) {
        try eventLoop(&inputs);

        if (inputs.inputs[0].released) {
            exit = true;
        }

        if (update_screen) {
            try renderer.setRenderDrawColor(255, 255, 255, 255);
            try renderer.clear();
            try objects.draw(renderer);
            try renderer.present();
            update_screen = false;
        }
    }
}

fn eventLoop(inputs: *Inputs) !void {
    inputs.resetKeys();
    var event: sdl.C.SDL_Event = undefined;
    while (sdl.C.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.C.SDL_EVENT_KEY_DOWN => switch (event.key.scancode) {
                sdl.C.SDL_SCANCODE_ESCAPE => inputs.keyDown(0),
                else => continue,
            },
            sdl.C.SDL_EVENT_KEY_UP => switch (event.key.scancode) {
                sdl.C.SDL_SCANCODE_ESCAPE => inputs.keyUp(0),
                else => continue,
            },
            sdl.C.SDL_EVENT_QUIT => exit = true,
            sdl.C.SDL_EVENT_WINDOW_RESIZED => {
                const win_size = try window.getWinSize();
                const x_scale: f32 = @as(f32, @floatFromInt(win_size.width)) / @as(f32, @floatFromInt(window_start_width));
                const y_scale: f32 = @as(f32, @floatFromInt(win_size.height)) / @as(f32, @floatFromInt(window_start_height));
                scale = @min(x_scale, y_scale);
                reset_sprites = true;
                update_screen = true;
            },
            else => continue,
        }
    }
}
