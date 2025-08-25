//! TODO: Use new writer and reader interface instead of deprecated functions
//! TODO: Change the starting_memory file to be only as big as it needs to be (Don't have a hex editor installed right now and can't be bothered)

const std = @import("std");
const builtin = @import("builtin");
var debug_alloc = if (builtin.mode == .Debug) std.heap.DebugAllocator(.{}).init else null;
const alloc = if (builtin.mode == .Debug) debug_alloc.allocator() else std.heap.c_allocator;
const sdl = @import("sdl_bindings");
const Inputs = @import("input").Inputs;
const Interpreter = @import("interpreter.zig").Interpreter;
const AudioStream = @import("8bit_sound.zig").AudioStream;
const args_parser = @import("args.zig");
var pixel_size: i32 = 10;
var exit = false;

const PlayField = struct {
    rect: sdl.rect.Frect = undefined,

    pub fn draw(self: *@This(), renderer: sdl.render.Renderer) !void {
        try renderer.setRenderDrawColor(255, 0, 0, 255);
        try renderer.renderRect(&self.rect);
    }
};

var window: sdl.render.Window = undefined;
var playfield: PlayField = PlayField{};
var update_screen = false;
var change_window = true;

pub fn main() !void {
    defer if (builtin.mode == .Debug) {
        _ = debug_alloc.deinit();
    };
    var args = args_parser.handleArgs(alloc) catch |err| {
        if (err == error.HelpAsked) return else return err;
    };
    errdefer args.deinit(alloc);

    const mem = try getProgram(alloc, args);
    defer alloc.free(mem);
    // This may seem bad but it's not (trust me)
    args.deinit(alloc);

    var inputs = try Inputs.init(alloc, 2);
    defer inputs.deinit(alloc);

    try sdl.init.initSDL(.{ .audio = true, .video = true, .events = true });
    defer sdl.init.deinitSDL();

    window = try sdl.render.Window.init("interpreter", 64 * pixel_size, 32 * pixel_size, .{ .fullsceen = args.fullscreen, .resizable = true });
    defer window.deinit();
    window.sync() catch |err| std.log.warn("{s}", .{@errorName(err)});

    var renderer = try sdl.render.Renderer.init(window);
    defer renderer.deinit();

    var audio_stream = try AudioStream.init();
    defer audio_stream.deinit();

    var interpreter = try Interpreter.init(alloc, mem, args);
    defer interpreter.deinit(alloc);

    // In case I want to test the interpreter without running even one instruction
    if (args.run_time == 0) exit = true;

    while (!exit) {
        var interpreter_base = interpreter.getBase();
        const frame_start = sdl.C.SDL_GetTicksNS();

        try eventLoop(&interpreter_base.user_inputs, &inputs);

        if (inputs.inputs[0].released) {
            exit = true;
        } else if (inputs.inputs[1].released) {
            try window.toggleFullscreen();
            window.sync() catch |err| std.log.warn("{s}", .{@errorName(err)});
            change_window = true;
        }

        const maybe_work = try interpreter.execNextIntstruction(alloc);
        if (maybe_work) |work| {
            switch (work) {
                .resolution_changed => change_window = true,
                .update_screen => update_screen = true,
                .exit => exit = true,
            }
        }

        if (change_window) {
            const win_size = try window.getWinSize();
            if (@divTrunc(win_size.width, interpreter_base.display_w) < @divTrunc(win_size.height, interpreter_base.display_h)) {
                pixel_size = @divTrunc(win_size.width, interpreter_base.display_w);
            } else {
                pixel_size = @divTrunc(win_size.height, interpreter_base.display_h);
            }
            playfield.rect.x = @floatFromInt(@divTrunc(win_size.width - interpreter_base.display_w * pixel_size, 2));
            playfield.rect.y = @floatFromInt(@divTrunc(win_size.height - interpreter_base.display_h * pixel_size, 2));
            playfield.rect.w = @floatFromInt(interpreter_base.display_w * pixel_size);
            playfield.rect.h = @floatFromInt(interpreter_base.display_h * pixel_size);
            update_screen = true;
        }

        if (update_screen) {
            try renderer.setRenderDrawColor(1, 1, 1, 255);
            try renderer.clear();
            try playfield.draw(renderer);
            try renderer.setRenderDrawColor(255, 255, 255, 255);
            var x: i32 = 0;
            var y: i32 = 0;

            for (interpreter_base.display_buffer) |val| {
                if (val == 1) {
                    const rect = sdl.rect.Irect{
                        .x = (x * pixel_size) + @as(i32, @intFromFloat(playfield.rect.x)),
                        .y = (y * pixel_size) + @as(i32, @intFromFloat(playfield.rect.y)),
                        .w = pixel_size,
                        .h = pixel_size,
                    };
                    try renderer.renderFillRect(@constCast(&rect.toFrect()));
                }
                x += 1;
                if (x >= interpreter_base.display_w) {
                    x -= interpreter_base.display_w;
                    y += 1;
                }
            }
            try renderer.present();
            update_screen = false;
        }

        if (interpreter_base.sound_timer > 1) try audio_stream.play_sound(alloc, interpreter_base.sound_timer);

        if (args.run_time) |val| {
            if (val <= interpreter_base.hertz_counter) exit = true;
        }

        const frame_end = sdl.C.SDL_GetTicksNS();
        if (frame_end - frame_start <= 1_666_666) {
            sdl.C.SDL_DelayNS(1_666_666 - (frame_end - frame_start));
        }
    }
}

fn eventLoop(interpreter_inputs: *Inputs, inputs: *Inputs) !void {
    interpreter_inputs.resetKeys();
    inputs.resetKeys();
    var event: sdl.C.SDL_Event = undefined;
    while (sdl.C.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.C.SDL_EVENT_KEY_DOWN => switch (event.key.scancode) {
                sdl.C.SDL_SCANCODE_1 => interpreter_inputs.keyDown(1),
                sdl.C.SDL_SCANCODE_2 => interpreter_inputs.keyDown(2),
                sdl.C.SDL_SCANCODE_3 => interpreter_inputs.keyDown(3),
                sdl.C.SDL_SCANCODE_Q => interpreter_inputs.keyDown(4),
                sdl.C.SDL_SCANCODE_W => interpreter_inputs.keyDown(5),
                sdl.C.SDL_SCANCODE_E => interpreter_inputs.keyDown(6),
                sdl.C.SDL_SCANCODE_A => interpreter_inputs.keyDown(7),
                sdl.C.SDL_SCANCODE_S => interpreter_inputs.keyDown(8),
                sdl.C.SDL_SCANCODE_D => interpreter_inputs.keyDown(9),
                sdl.C.SDL_SCANCODE_X => interpreter_inputs.keyDown(0),
                sdl.C.SDL_SCANCODE_Z => interpreter_inputs.keyDown(0xA),
                sdl.C.SDL_SCANCODE_C => interpreter_inputs.keyDown(0xB),
                sdl.C.SDL_SCANCODE_4 => interpreter_inputs.keyDown(0xC),
                sdl.C.SDL_SCANCODE_R => interpreter_inputs.keyDown(0xD),
                sdl.C.SDL_SCANCODE_F => interpreter_inputs.keyDown(0xE),
                sdl.C.SDL_SCANCODE_V => interpreter_inputs.keyDown(0xF),
                sdl.C.SDL_SCANCODE_ESCAPE => inputs.keyDown(0),
                sdl.C.SDL_SCANCODE_HOME => inputs.keyDown(1),
                else => continue,
            },
            sdl.C.SDL_EVENT_KEY_UP => switch (event.key.scancode) {
                sdl.C.SDL_SCANCODE_1 => interpreter_inputs.keyUp(1),
                sdl.C.SDL_SCANCODE_2 => interpreter_inputs.keyUp(2),
                sdl.C.SDL_SCANCODE_3 => interpreter_inputs.keyUp(3),
                sdl.C.SDL_SCANCODE_Q => interpreter_inputs.keyUp(4),
                sdl.C.SDL_SCANCODE_W => interpreter_inputs.keyUp(5),
                sdl.C.SDL_SCANCODE_E => interpreter_inputs.keyUp(6),
                sdl.C.SDL_SCANCODE_A => interpreter_inputs.keyUp(7),
                sdl.C.SDL_SCANCODE_S => interpreter_inputs.keyUp(8),
                sdl.C.SDL_SCANCODE_D => interpreter_inputs.keyUp(9),
                sdl.C.SDL_SCANCODE_X => interpreter_inputs.keyUp(0),
                sdl.C.SDL_SCANCODE_Z => interpreter_inputs.keyUp(0xA),
                sdl.C.SDL_SCANCODE_C => interpreter_inputs.keyUp(0xB),
                sdl.C.SDL_SCANCODE_4 => interpreter_inputs.keyUp(0xC),
                sdl.C.SDL_SCANCODE_R => interpreter_inputs.keyUp(0xD),
                sdl.C.SDL_SCANCODE_F => interpreter_inputs.keyUp(0xE),
                sdl.C.SDL_SCANCODE_V => interpreter_inputs.keyUp(0xF),
                sdl.C.SDL_SCANCODE_ESCAPE => inputs.keyUp(0),
                sdl.C.SDL_SCANCODE_HOME => inputs.keyUp(1),
                else => continue,
            },
            sdl.C.SDL_EVENT_QUIT => exit = true,
            sdl.C.SDL_EVENT_WINDOW_RESIZED => change_window = true,
            else => continue,
        }
    }
}

/// Returned slice is on heap
fn getProgram(allocator: std.mem.Allocator, args: args_parser.Args) ![]u8 {
    const prog_file = try std.fs.cwd().openFile(args.file_name.?, .{});
    defer prog_file.close();

    const prog_file_contents = try prog_file.readToEndAlloc(allocator, try prog_file.getEndPos());
    defer allocator.free(prog_file_contents);

    const mem_file = try std.fs.cwd().openFile("starting_memory", .{});
    defer mem_file.close();
    const mem_file_contents = try mem_file.readToEndAlloc(allocator, try mem_file.getEndPos());
    errdefer allocator.free(mem_file_contents);

    mem_file_contents = try allocator.realloc(mem_file_contents, @min(mem_file_contents.len, args.program_start_index + prog_file_contents.len));

    @memcpy(mem_file_contents[args.program_start_index .. args.program_start_index + prog_file_contents.len], prog_file_contents);
    return mem_file_contents;
}
