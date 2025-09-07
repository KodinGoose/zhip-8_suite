//! TODO: Change the starting_memory file to be only as big as it needs to be (Don't have a hex editor installed right now and can't be bothered)

const std = @import("std");
const builtin = @import("builtin");
var debug_alloc = if (builtin.mode == .Debug) std.heap.DebugAllocator(.{}).init else null;
const alloc = if (builtin.mode == .Debug) debug_alloc.allocator() else std.heap.c_allocator;
const sdl = @import("sdl_bindings");
const Input = @import("shared").Input;
const Interpreter = @import("interpreter.zig").Interpreter;
const AudioStream = @import("8bit_sound.zig").AudioStream;
const args_parser = @import("args.zig");
var pixel_size: i32 = 1;
var exit = false;

const PlayField = struct {
    rect: sdl.rect.Irect = undefined,

    pub fn draw(self: *@This(), draw_to: *sdl.render.Surface) !void {
        try draw_to.blitRect(&self.rect, .{ .r = 255, .g = 0, .b = 0, .a = 255 });
        var rect = sdl.rect.Irect{ .x = self.rect.x + 1, .y = self.rect.y + 1, .w = self.rect.w - 2, .h = self.rect.h - 2 };
        try draw_to.blitRect(&rect, .{ .r = 1, .g = 1, .b = 1, .a = 255 });
    }
};

var window: sdl.render.Window = undefined;
var playfield: PlayField = PlayField{};
var update_screen = false;
var update_window = true;
var auto_sleep = true;

pub fn main() !void {
    var stderr_buf: [4096]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

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

    var inputs = try Input.init(alloc, 2);
    defer inputs.deinit(alloc);

    try sdl.init.initSDL(.{ .audio = true, .video = true, .events = true });
    defer sdl.init.deinitSDL();

    var interpreter = try Interpreter.init(alloc, mem, args, stderr);
    defer interpreter.deinit(alloc);

    if (interpreter._tag != .chip_64) pixel_size = 10;

    window = try sdl.render.Window.init("interpreter", interpreter.getDrawSurface().w, interpreter.getDrawSurface().h, .{ .fullsceen = args.fullscreen, .resizable = true });
    defer window.deinit();
    window.sync() catch |err| std.log.warn("{s}", .{@errorName(err)});

    var audio_stream = try AudioStream.init();
    defer audio_stream.deinit();

    // In case I want to test the interpreter without running even one instruction
    if (args.run_time == 0) exit = true;

    while (!exit) {
        const frame_start = sdl.C.SDL_GetTicksNS();

        try eventLoop(interpreter.getInputsPointer(), &inputs);

        if (inputs.inputs[0].released) {
            exit = true;
        } else if (inputs.inputs[1].released) {
            try window.toggleFullscreen();
            window.sync() catch |err| std.log.warn("{s}", .{@errorName(err)});
            update_window = true;
        }

        const maybe_work = interpreter.execNextIntstruction(alloc) catch |err| {
            if (err == error.ErrorPrinted) return else return err;
        };
        if (maybe_work) |work| {
            switch (work) {
                .enable_auto_sleep => auto_sleep = true,
                .disable_auto_sleep => auto_sleep = false,
                .toggle_window_size_lock => try window.toggleResizable(),
                .match_window_to_resolution => {
                    try window.setWinSize(interpreter.getDrawSurface().w, interpreter.getDrawSurface().h);
                    try window.sync();
                    update_window = true;
                },
                .resolution_changed => update_window = true,
                .update_screen => update_screen = true,
                .exit => exit = true,
            }
        }

        if (update_window) {
            const inter_surf = interpreter.getDrawSurface();
            const win_size = try window.getWinSize();
            if (@divTrunc(win_size.width, inter_surf.w) < @divTrunc(win_size.height, inter_surf.h)) {
                pixel_size = @divTrunc(win_size.width, inter_surf.w);
            } else {
                pixel_size = @divTrunc(win_size.height, inter_surf.h);
            }
            playfield.rect.x = @divTrunc(win_size.width - inter_surf.w * pixel_size, 2) - 1;
            playfield.rect.y = @divTrunc(win_size.height - inter_surf.h * pixel_size, 2) - 1;
            playfield.rect.w = (inter_surf.w * pixel_size) + 2;
            playfield.rect.h = (inter_surf.h * pixel_size) + 2;
            update_window = false;
            update_screen = true;
        }

        if (update_screen) {
            var window_surface = try window.getSurface();

            try window_surface.clearSurface(.{ .r = 1.0 / 255.0, .g = 1.0 / 255.0, .b = 1.0 / 255.0, .a = 1.0 });

            try playfield.draw(window_surface);

            const inter_surf = interpreter.getDrawSurface();
            var tmp_surf = try inter_surf.scaleSurface(inter_surf.w * pixel_size, inter_surf.h * pixel_size, .nearest);
            defer tmp_surf.deinit();
            try window_surface.blitSurface(tmp_surf, playfield.rect.x + 1, playfield.rect.y + 1);

            try window.updateSurface();
            update_screen = false;
        }

        if (interpreter.getSoundTimer() > 1) try audio_stream.play_sound(alloc, interpreter.getSoundTimer());

        if (args.run_time) |val| {
            if (val <= interpreter.getHertzCounter()) exit = true;
        }

        if (auto_sleep) {
            const frame_end = sdl.C.SDL_GetTicksNS();
            if (frame_end - frame_start <= 1_666_666) {
                sdl.C.SDL_DelayNS(1_666_666 - (frame_end - frame_start));
            }
        }
    }
}

fn eventLoop(interpreter_inputs: *Input, inputs: *Input) !void {
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
            sdl.C.SDL_EVENT_WINDOW_RESIZED => update_window = true,
            // Checking for these two events shouldn't be required but on some
            // target platforms we don't get a window resized event when exiting fullscreen
            sdl.C.SDL_EVENT_WINDOW_ENTER_FULLSCREEN => update_window = true,
            sdl.C.SDL_EVENT_WINDOW_LEAVE_FULLSCREEN => update_window = true,
            else => continue,
        }
    }
}

/// Returned slice is on heap
/// TODO: Stop using deprecated functions
fn getProgram(allocator: std.mem.Allocator, args: args_parser.Args) ![]u8 {
    const prog_file = try std.fs.cwd().openFile(args.file_name.?, .{});
    defer prog_file.close();

    const prog_file_contents = try prog_file.readToEndAlloc(allocator, try prog_file.getEndPos());
    defer allocator.free(prog_file_contents);

    const mem_file = try std.fs.cwd().openFile("starting_memory", .{});
    defer mem_file.close();
    var mem_file_contents = try mem_file.readToEndAlloc(allocator, try mem_file.getEndPos());
    errdefer allocator.free(mem_file_contents);

    // zig fmt: off
    const code_start: usize =
        if (args.program_start_index == null)
            if (args.build == .chip_64) 0 else 0x200
        else
            args.program_start_index.?;
    // zig fmt: on

    mem_file_contents = try allocator.realloc(
        mem_file_contents,
        if (args.build != .chip_64) @max(
            mem_file_contents.len,
            code_start + prog_file_contents.len,
        ) else code_start + prog_file_contents.len,
    );

    @memcpy(mem_file_contents[code_start .. code_start + prog_file_contents.len], prog_file_contents);
    return mem_file_contents;
}
