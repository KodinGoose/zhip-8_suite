const std = @import("std");

const Input = @import("shared").Input;
const input_len: usize = @intCast(@import("sdl_bindings").C.SDL_SCANCODE_COUNT);

const ExtraWork = @import("base.zig").ExtraWork;
const Args = @import("../args.zig").Args;
const Stack = @import("shared").Stack.Stack(usize);
const ErrorHandler = @import("../error.zig").Handler;

pub const Interpreter = struct {
    prg_ptr: usize = 0,
    stack: Stack,
    mem: []u8,
    draw_buf: []u8,
    inputs: Input,
    rand_gen: std.Random.DefaultPrng,
    _error_handler: ErrorHandler,

    /// mem includes program code
    /// mem in unmodified
    pub fn init(allocator: std.mem.Allocator, mem: []u8, args: Args) !@This() {
        const draw_buf = try allocator.alloc(u8, 64 * 128);
        errdefer allocator.free(draw_buf);
        for (draw_buf) |*byte| byte.* = 0;
        return Interpreter{
            .prg_ptr = args.program_start_index orelse 0,
            .stack = .init(allocator, 16),
            .mem = try allocator.dupe(u8, mem),
            .draw_buf = draw_buf,
            .inputs = .init(allocator, input_len),
            .rand_gen = .init(@truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))),
            ._error_handler = .{
                ._panic_on_error = args.interpreter_panic_on_error,
                ._max_len = 4096,
                // Client mode will be removed
                ._client_mode = args.client_mode,
            },
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.stack.deinit(allocator);
        allocator.free(self.mem);
        self.inputs.deinit(allocator);
        self._error_handler.flush() catch {};
        self._error_handler.deinit(allocator);
    }

    pub fn execNextInstruction(self: *@This(), allocator: std.mem.Allocator) !?ExtraWork {
        switch (self.mem[self.prg_ptr]) {
            0x00 => self.prg_ptr -%= 1,
            0x01 => return ExtraWork.exit,
            0x02 => {
                for (self.draw_buf) |*byte| byte.* = 0;
                return ExtraWork.update_screen;
            },
            0x03 => self.prg_ptr = self.stack.pop() catch |err| if (err == error.OutOfBounds) {
                try self._error_handler.handleInterpreterError(allocator, "Out of bounds of stack", self.mem[self.prog_ptr], self.prg_ptr, err);
            },
            0x04 => {
                const collumns = std.mem.bigToNative(u16, @bitCast(self.mem[self.prg_ptr + 1 .. self.prg_ptr + 1 + 2]));
                // const collumns = (@as(usize, self.mem[self.prg_ptr + 1]) << 8) + self.mem[self.prg_ptr + 2];
                const rows = std.mem.bigToNative(u16, @bitCast(self.mem[self.prg_ptr + 3 .. self.prg_ptr + 3 + 2]));
                // const rows = (@as(usize, self.mem[self.prg_ptr + 3]) << 8) + self.mem[self.prg_ptr + 4];
                self.draw_buf = try allocator.realloc(
                    self.draw_buf,
                    collumns * rows,
                );
                for (self.draw_buf) |*byte| byte.* = 0;
                self.prg_ptr +%= 4;
                return ExtraWork.resolution_changed;
            },
        }
        self.prg_ptr +%= 1;
    }
};
