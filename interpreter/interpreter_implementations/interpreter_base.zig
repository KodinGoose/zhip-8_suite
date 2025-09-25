const std = @import("std");
const builtin = @import("builtin");
const Inputs = @import("input").Inputs;
const Stack = @import("../stack.zig").Stack(usize);
const ErrorHandler = @import("../error.zig").Handler;
const Args = @import("../args.zig").Args;

pub const Byte = packed struct {
    /// Short for lower, shortened because of long code lines
    l: u4,
    /// Short for upper, shortened because of long code lines
    u: u4,
};

/// These are things the interpreter cannot do by itself and must be done by the caller
pub const ExtraWork = enum(u8) {
    resolution_changed,
    update_screen,
    exit,
};

pub const InterpreterBase = struct {
    /// Taking inputs is the job of the caller
    user_inputs: Inputs,
    display_buffer: []u1,
    /// Type is i32 due to compatibility with C
    display_w: i32,
    /// Type is i32 due to compatibility with C
    display_h: i32,
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
    pub fn init(allocator: std.mem.Allocator, mem: []u8, args: Args, display_w: i32, display_h: i32) !@This() {
        const interpreter_base = InterpreterBase{
            .user_inputs = try Inputs.init(allocator, 16),
            .display_buffer = try allocator.alloc(u1, @as(u32, @bitCast(display_w * display_h))),
            .display_w = display_w,
            .display_h = display_h,
            .mem = @ptrCast(mem),
            .prg_ptr = args.program_start_index,
            .stack = try Stack.init(allocator, 16),

            .error_handler = ErrorHandler{ ._panic_on_error = args.interpreter_panic_on_error, ._max_len = 4096, ._client_mode = args.client_mode },
            .rng = std.Random.DefaultPrng.init(@intCast(@as(u128, @bitCast(std.time.nanoTimestamp())))),
        };
        for (0..interpreter_base.display_buffer.len) |i| {
            interpreter_base.display_buffer[i] = 0;
        }

        return interpreter_base;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.display_buffer);
        self.stack.deinit(allocator);
        self.error_handler.flush() catch {};
        self.error_handler.deinit(allocator);
        self.user_inputs.deinit(allocator);
    }

    pub fn changeResolution(self: *@This(), allocator: std.mem.Allocator, w: i32, h: i32) !void {
        allocator.free(self.display_buffer);
        self.display_buffer = try allocator.alloc(u1, @as(u32, @bitCast(w)) * @as(u32, @bitCast(h)));
        for (0..self.display_buffer.len) |i| self.display_buffer[i] = 0;
        self.display_w = w;
        self.display_h = h;
    }
};

pub fn getAddress(cur_byte: Byte, next_byte: Byte) u12 {
    return (@as(u12, cur_byte.l) << 8) + @as(u8, @bitCast(next_byte));
}
