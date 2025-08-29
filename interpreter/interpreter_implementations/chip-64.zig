const std = @import("std");

const Input = @import("shared").Input;
const input_len: usize = @intCast(@import("sdl_bindings").C.SDL_SCANCODE_COUNT);

const ExtraWork = @import("base.zig").ExtraWork;
const Args = @import("../args.zig").Args;
const Stack = @import("shared").Stack.Stack(u64);
const ErrorHandler = @import("../error.zig").Handler;

const draw_buf_start_w = 512;
const draw_buf_start_h = 256;

pub const Interpreter = struct {
    prg_ptr: usize = 0,
    stack: Stack,
    mem: []u8,
    draw_buf: []u8,
    draw_w: u16 = draw_buf_start_w,
    draw_h: u16 = draw_buf_start_h,
    inputs: Input,
    rand_gen: std.Random.DefaultPrng,
    sound_timer: u8 = 0,
    hertz_counter: usize = 0,
    _error_handler: ErrorHandler,

    /// mem includes program code
    /// mem in unmodified
    pub fn init(allocator: std.mem.Allocator, mem: []u8, args: Args, err_writer: *std.Io.Writer) !@This() {
        const draw_buf = try allocator.alloc(u8, draw_buf_start_w * draw_buf_start_h);
        errdefer allocator.free(draw_buf);
        for (draw_buf) |*byte| byte.* = 0;

        return Interpreter{
            .prg_ptr = args.program_start_index orelse 0,
            .stack = try .init(allocator, 16),
            .mem = try allocator.dupe(u8, mem),
            .draw_buf = draw_buf,
            .inputs = try .init(allocator, input_len),
            .rand_gen = .init(@truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))),
            ._error_handler = .{
                ._writer = err_writer,
                ._panic_on_error = args.interpreter_panic_on_error,
            },
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.stack.deinit(allocator);
        allocator.free(self.mem);
        allocator.free(self.draw_buf);
        self.inputs.deinit(allocator);
        self._error_handler._writer.flush() catch {};
        self._error_handler.writeErrorCount();
    }

    pub fn execNextInstruction(self: *@This(), allocator: std.mem.Allocator) !?ExtraWork {
        var extra_work: ?ExtraWork = null;

        switch (self.mem[self.prg_ptr]) {
            0x00 => self.prg_ptr -%= 1,
            0x01 => extra_work = .exit,
            0x02 => {
                for (self.draw_buf) |*byte| byte.* = 0;
                extra_work = .update_screen;
            },
            // Truncate has no effect on 64 bit archs but is required to run on 32 bit archs and is safe
            // since you can't have more memory than 2^32-1 memory on 32 bit archs
            0x03 => self.prg_ptr = @truncate(self.stack.pop() catch |err|
                if (err == error.OutOfBounds) {
                    try self._error_handler.handleInterpreterError("Out of bounds of stack", self.mem[self.prg_ptr], self.prg_ptr, err);
                    // We return error no matter what because continuing likely wouldn't lead to any more useful errors
                    // and could easily lead to the execution of unwanted code (executing data as code for example)
                    return error.ErrorPrinted;
                } else return err),
            0x04 => {
                extra_work = .match_window_to_resolution;
            },
            0x05 => {
                // u32 is just enough to store u16 * u16
                const collumns = (@as(u32, self.mem[self.prg_ptr + 1]) << 8) + self.mem[self.prg_ptr + 2];
                const rows = (@as(u32, self.mem[self.prg_ptr + 3]) << 8) + self.mem[self.prg_ptr + 4];
                self.draw_buf = try allocator.realloc(
                    self.draw_buf,
                    collumns * rows,
                );
                for (self.draw_buf) |*byte| byte.* = 0;
                self.draw_w = @intCast(collumns);
                self.draw_h = @intCast(rows);
                self.prg_ptr +%= 4;
                extra_work = .resolution_changed;
            },
            0x06...0x09 => {
                try self._error_handler.handleInterpreterError("Unimplemented instruction", self.mem[self.prg_ptr], self.prg_ptr, error.UnimplementedInstruction);
            },
            0x10 => {
                self.prg_ptr = self.readAddress(self.prg_ptr + 1) -% 1;
            },
            0x17 => {
                const address = self.readAddress(self.prg_ptr + 1);
                try self.stack.push(allocator, address);
                self.prg_ptr = address -% 1;
            },
            else => try self._error_handler.handleInterpreterError("Unknown instruction", self.mem[self.prg_ptr], self.prg_ptr, error.UnknownInstruction),
        }
        self.prg_ptr +%= 1;

        return extra_work;
    }

    fn readAddress(self: *@This(), at: u64) u64 {
        // zig fmt: off
        return
            (@as(u64, self.mem[at + 0]) << 56) + 
            (@as(u64, self.mem[at + 1]) << 48) + 
            (@as(u64, self.mem[at + 2]) << 40) + 
            (@as(u64, self.mem[at + 3]) << 32) + 
            (@as(u64, self.mem[at + 4]) << 24) + 
            (@as(u64, self.mem[at + 5]) << 16) + 
            (@as(u64, self.mem[at + 6]) << 8) + 
            (@as(u64, self.mem[at + 7]) << 0);
        // zig fmt: on
    }
};
