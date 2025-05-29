const std = @import("std");
const builtin = @import("builtin");
var debug_allocator = if (builtin.mode == .Debug) std.heap.DebugAllocator(.{}).init else null;
const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;
const sdl = @import("sdl_bindings");
const Inputs = @import("input").Inputs;
const Interpreter = @import("interpreter.zig").Interpreter;
const AudioStream = @import("8bit_sound.zig").AudioStream;
const args_parser = @import("args.zig");
var pixel_size: i32 = 10;
var exit = false;

/// Returned slice is on heap
fn getProgram(args: args_parser.Args) ![]u8 {
    const file = try std.fs.cwd().openFile(args.file_name.?, .{});
    defer file.close();
    const file_contents = file.readToEndAlloc(allocator, 4096) catch |err| {
        if (err == error.FileTooBig) {
            try std.io.getStdOut().writeAll("Maximum size for a program is 4096 bytes");
        }
        return err;
    };
    defer allocator.free(file_contents);

    const mem_file = try std.fs.cwd().openFile("starting_memory", .{});
    defer mem_file.close();
    const mem_file_contents = mem_file.readToEndAlloc(allocator, 4096) catch |err| {
        if (err == error.FileTooBig) {
            try std.io.getStdOut().writeAll("Corrupt starting memory file\nThe file must be 4096 bytes\n");
        }
        return err;
    };
    if (mem_file_contents.len != 4096) {
        try std.io.getStdOut().writeAll("Corrupt starting memory file\nThe file must be 4096 bytes\n");
        return error.FileTooSmall;
    }

    for (file_contents, 0..) |byte, i| {
        mem_file_contents[args.program_start_index + i] = byte;
    }
    return mem_file_contents;
}

const PlayField = struct {
    rect: sdl.rect.Frect = undefined,

    pub fn draw(self: *@This(), renderer: sdl.render.Renderer) !void {
        try renderer.renderRect(&self.rect);
    }
};

var window: sdl.render.Window = undefined;
var playfield: PlayField = PlayField{};
var update_screen = false;

pub fn main() !void {
    var args = args_parser.handleArgs(allocator) catch |err| {
        if (err == error.HelpAsked) return else return err;
    };
    const mem = try getProgram(args);
    defer allocator.free(mem);
    // This may seem bad but it's not (trust me)
    args.deinit(allocator);

    var inputs = try Inputs.init(allocator, 2);
    defer inputs.deinit(allocator);

    try sdl.init.initSDL(.{ .audio = true, .video = true, .events = true });
    defer sdl.init.deinitSDL();

    window = try sdl.render.Window.init("interpreter", 64 * pixel_size, 32 * pixel_size, .{ .fullsceen = args.fullscreen, .resizable = true });
    defer window.deinit();
    window.sync() catch |err| std.log.warn("{s}", .{@errorName(err)});
    {
        const win_size = try window.getWinSize();
        if (@divTrunc(win_size.width, 64) < @divTrunc(win_size.height, 32)) {
            pixel_size = @divTrunc(win_size.width, 64);
        } else {
            pixel_size = @divTrunc(win_size.height, 32);
        }
        playfield.rect.x = @floatFromInt(@divTrunc(win_size.width - 64 * pixel_size, 2));
        playfield.rect.y = @floatFromInt(@divTrunc(win_size.height - 32 * pixel_size, 2));
        playfield.rect.w = @floatFromInt(64 * pixel_size);
        playfield.rect.h = @floatFromInt(32 * pixel_size);
    }

    var renderer = try sdl.render.Renderer.init(window);
    defer renderer.deinit();

    var audio_stream = try AudioStream.init();
    defer audio_stream.deinit();

    var interpreter = try Interpreter.init(allocator, mem, 64, 32, args);
    defer interpreter.deinit(allocator);

    // In case I want to test the interpreter without running even one instruction
    if (args.run_time == 0) exit = true;

    while (!exit) {
        const frame_start = sdl.C.SDL_GetTicksNS();
        try eventLoop(&interpreter.user_inputs, &inputs);

        if (inputs.inputs[0].released) {
            exit = true;
        } else if (inputs.inputs[1].released) {
            try window.toggleFullscreen();
            window.sync() catch |err| std.log.warn("{s}", .{@errorName(err)});
            const win_size = try window.getWinSize();
            if (@divTrunc(win_size.width, 64) < @divTrunc(win_size.height, 32)) {
                pixel_size = @divTrunc(win_size.width, 64);
            } else {
                pixel_size = @divTrunc(win_size.height, 32);
            }
            playfield.rect.x = @floatFromInt(@divTrunc(win_size.width - 64 * pixel_size, 2));
            playfield.rect.y = @floatFromInt(@divTrunc(win_size.height - 32 * pixel_size, 2));
            playfield.rect.w = @floatFromInt(64 * pixel_size);
            playfield.rect.h = @floatFromInt(32 * pixel_size);
            update_screen = true;
        }

        if (try interpreter.execNextInstruction(allocator)) |work| {
            switch (work) {
                .update_screen => update_screen = true,
                .exit => exit = true,
            }
        }

        if (update_screen) {
            try renderer.setRenderDrawColor(1, 1, 1, 255);
            try renderer.clear();
            try renderer.setRenderDrawColor(255, 0, 0, 255);
            try playfield.draw(renderer);
            var x: i32 = 0;
            var y: i32 = 0;
            try renderer.setRenderDrawColor(255, 255, 255, 255);
            for (interpreter._display_buffer) |val| {
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
                if (x >= interpreter._display_w) {
                    x -= interpreter._display_w;
                    y += 1;
                }
            }
            try renderer.present();
            update_screen = false;
        }

        if (interpreter._sound_timer > 1) {
            try audio_stream.play_sound(allocator, interpreter._sound_timer);
        }

        if (args.run_time) |val| {
            if (val <= interpreter._hertz_counter) exit = true;
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
                sdl.C.SDL_SCANCODE_W => interpreter_inputs.keyDown(1),
                sdl.C.SDL_SCANCODE_E => interpreter_inputs.keyDown(2),
                sdl.C.SDL_SCANCODE_R => interpreter_inputs.keyDown(3),
                sdl.C.SDL_SCANCODE_S => interpreter_inputs.keyDown(4),
                sdl.C.SDL_SCANCODE_D => interpreter_inputs.keyDown(5),
                sdl.C.SDL_SCANCODE_F => interpreter_inputs.keyDown(6),
                sdl.C.SDL_SCANCODE_X => interpreter_inputs.keyDown(7),
                sdl.C.SDL_SCANCODE_C => interpreter_inputs.keyDown(8),
                sdl.C.SDL_SCANCODE_V => interpreter_inputs.keyDown(9),
                sdl.C.SDL_SCANCODE_SPACE => interpreter_inputs.keyDown(0),
                sdl.C.SDL_SCANCODE_Q => interpreter_inputs.keyDown(0xA),
                sdl.C.SDL_SCANCODE_A => interpreter_inputs.keyDown(0xB),
                sdl.C.SDL_SCANCODE_5 => interpreter_inputs.keyDown(0xC),
                sdl.C.SDL_SCANCODE_T => interpreter_inputs.keyDown(0xD),
                sdl.C.SDL_SCANCODE_G => interpreter_inputs.keyDown(0xE),
                sdl.C.SDL_SCANCODE_B => interpreter_inputs.keyDown(0xF),
                sdl.C.SDL_SCANCODE_ESCAPE => inputs.keyDown(0),
                sdl.C.SDL_SCANCODE_HOME => inputs.keyDown(1),
                else => continue,
            },
            sdl.C.SDL_EVENT_KEY_UP => switch (event.key.scancode) {
                sdl.C.SDL_SCANCODE_W => interpreter_inputs.keyUp(1),
                sdl.C.SDL_SCANCODE_E => interpreter_inputs.keyUp(2),
                sdl.C.SDL_SCANCODE_R => interpreter_inputs.keyUp(3),
                sdl.C.SDL_SCANCODE_S => interpreter_inputs.keyUp(4),
                sdl.C.SDL_SCANCODE_D => interpreter_inputs.keyUp(5),
                sdl.C.SDL_SCANCODE_F => interpreter_inputs.keyUp(6),
                sdl.C.SDL_SCANCODE_X => interpreter_inputs.keyUp(7),
                sdl.C.SDL_SCANCODE_C => interpreter_inputs.keyUp(8),
                sdl.C.SDL_SCANCODE_V => interpreter_inputs.keyUp(9),
                sdl.C.SDL_SCANCODE_SPACE => interpreter_inputs.keyUp(0),
                sdl.C.SDL_SCANCODE_Q => interpreter_inputs.keyUp(0xA),
                sdl.C.SDL_SCANCODE_A => interpreter_inputs.keyUp(0xB),
                sdl.C.SDL_SCANCODE_5 => interpreter_inputs.keyUp(0xC),
                sdl.C.SDL_SCANCODE_T => interpreter_inputs.keyUp(0xD),
                sdl.C.SDL_SCANCODE_G => interpreter_inputs.keyUp(0xE),
                sdl.C.SDL_SCANCODE_B => interpreter_inputs.keyUp(0xF),
                sdl.C.SDL_SCANCODE_ESCAPE => inputs.keyUp(0),
                sdl.C.SDL_SCANCODE_HOME => inputs.keyUp(1),
                else => continue,
            },
            sdl.C.SDL_EVENT_QUIT => exit = true,
            sdl.C.SDL_EVENT_WINDOW_RESIZED => {
                const win_size = try window.getWinSize();
                if (@divTrunc(win_size.width, 64) < @divTrunc(win_size.height, 32)) {
                    pixel_size = @divTrunc(win_size.width, 64);
                } else {
                    pixel_size = @divTrunc(win_size.height, 32);
                }
                playfield.rect.x = @floatFromInt(@divTrunc(win_size.width - 64 * pixel_size, 2));
                playfield.rect.y = @floatFromInt(@divTrunc(win_size.height - 32 * pixel_size, 2));
                playfield.rect.w = @floatFromInt(64 * pixel_size);
                playfield.rect.h = @floatFromInt(32 * pixel_size);
                update_screen = true;
            },
            else => continue,
        }
    }
}
