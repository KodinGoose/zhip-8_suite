const std = @import("std");
const builtin = @import("builtin");

const sdl_C = @import("sdl_bindings").C;

const Input = @import("shared").Input;
const Stack = @import("../stack.zig").Stack(usize);
const ErrorHandler = @import("../error.zig").Handler;
const Args = @import("../args.zig").Args;

const input_len: usize = @intCast(sdl_C.SDL_SCANCODE_COUNT);

pub const Byte = packed struct {
    /// Short for lower, shortened because of long code lines
    l: u4,
    /// Short for upper, shortened because of long code lines
    u: u4,
};

/// These are things the interpreter cannot do by itself and must be done by the caller
pub const ExtraWork = enum(u8) {
    enable_auto_sleep,
    disable_auto_sleep,
    toggle_window_size_lock,
    match_window_to_resolution,
    resolution_changed,
    update_screen,
    exit,
    halt,
};

pub const InterpreterBase = struct {
    /// Taking inputs is the job of the caller
    user_inputs: Input,
    draw_buf: []u1,
    /// Type is i32 due to compatibility with C
    draw_w: i32,
    /// Type is i32 due to compatibility with C
    draw_h: i32,
    mem: []Byte,
    prg_ptr: usize,
    /// Counts down once every 10 hertz
    sound_timer: u8 = 0,
    /// Counts down once every 10 hertz
    delay_timer: u8 = 0,
    hertz_counter: u64 = 0,
    stack: Stack,
    registers: [16]u8 = [1]u8{0} ** 16,
    address_register: usize = 0,

    error_handler: ErrorHandler,
    rng: std.Random.DefaultPrng,

    /// By passing in "mem" the caller gives up ownership until deinit is called after
    /// which it's once again owned by the caller
    /// display width and height is currently hardcoded because all our current Build's interpreters start in lores (64x32) mode
    pub fn init(allocator: std.mem.Allocator, mem: []u8, args: Args, display_w: i32, display_h: i32, err_writer: *std.Io.Writer) !@This() {
        const interpreter_base = InterpreterBase{
            .user_inputs = try Input.init(allocator, input_len),
            .draw_buf = try allocator.alloc(u1, @as(u32, @bitCast(display_w * display_h))),
            .draw_w = display_w,
            .draw_h = display_h,
            .mem = @ptrCast(mem),
            .prg_ptr = if (args.program_start_index == null) 512 else args.program_start_index.?,
            .stack = try Stack.init(allocator, 16),
            .error_handler = .{
                ._writer = err_writer,
                ._panic_on_error = args.interpreter_panic_on_error,
            },
            .rng = std.Random.DefaultPrng.init(@intCast(@as(u128, @bitCast(std.time.nanoTimestamp())))),
        };
        for (0..interpreter_base.draw_buf.len) |i| {
            interpreter_base.draw_buf[i] = 0;
        }

        return interpreter_base;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.draw_buf);
        self.stack.deinit(allocator);
        self.user_inputs.deinit(allocator);
        self.error_handler.writeErrorCount();
    }

    pub fn changeResolution(self: *@This(), allocator: std.mem.Allocator, w: i32, h: i32) !void {
        allocator.free(self.draw_buf);
        self.draw_buf = try allocator.alloc(u1, @as(u32, @bitCast(w)) * @as(u32, @bitCast(h)));
        for (0..self.draw_buf.len) |i| self.draw_buf[i] = 0;
        self.draw_w = w;
        self.draw_h = h;
    }
};

pub fn getAddress(cur_byte: Byte, next_byte: Byte) u12 {
    return (@as(u12, cur_byte.l) << 8) + @as(u8, @bitCast(next_byte));
}

pub fn convertInputsToScancode(register: u8) !i32 {
    return switch (register) {
        0x0 => sdl_C.SDL_SCANCODE_X,
        0x1 => sdl_C.SDL_SCANCODE_1,
        0x2 => sdl_C.SDL_SCANCODE_2,
        0x3 => sdl_C.SDL_SCANCODE_3,
        0x4 => sdl_C.SDL_SCANCODE_Q,
        0x5 => sdl_C.SDL_SCANCODE_W,
        0x6 => sdl_C.SDL_SCANCODE_E,
        0x7 => sdl_C.SDL_SCANCODE_A,
        0x8 => sdl_C.SDL_SCANCODE_S,
        0x9 => sdl_C.SDL_SCANCODE_D,
        0xA => sdl_C.SDL_SCANCODE_Z,
        0xB => sdl_C.SDL_SCANCODE_C,
        0xC => sdl_C.SDL_SCANCODE_4,
        0xD => sdl_C.SDL_SCANCODE_R,
        0xE => sdl_C.SDL_SCANCODE_F,
        0xF => sdl_C.SDL_SCANCODE_V,
        else => error.InvalidKey,
    };
}

pub fn convertScancodeToInputs(scancode: c_int) !u4 {
    return switch (scancode) {
        sdl_C.SDL_SCANCODE_X => 0x0,
        sdl_C.SDL_SCANCODE_1 => 0x1,
        sdl_C.SDL_SCANCODE_2 => 0x2,
        sdl_C.SDL_SCANCODE_3 => 0x3,
        sdl_C.SDL_SCANCODE_Q => 0x4,
        sdl_C.SDL_SCANCODE_W => 0x5,
        sdl_C.SDL_SCANCODE_E => 0x6,
        sdl_C.SDL_SCANCODE_A => 0x7,
        sdl_C.SDL_SCANCODE_S => 0x8,
        sdl_C.SDL_SCANCODE_D => 0x9,
        sdl_C.SDL_SCANCODE_Z => 0xA,
        sdl_C.SDL_SCANCODE_C => 0xB,
        sdl_C.SDL_SCANCODE_4 => 0xC,
        sdl_C.SDL_SCANCODE_R => 0xD,
        sdl_C.SDL_SCANCODE_F => 0xE,
        sdl_C.SDL_SCANCODE_V => 0xF,
        else => error.UnableToConvert,
    };
}
