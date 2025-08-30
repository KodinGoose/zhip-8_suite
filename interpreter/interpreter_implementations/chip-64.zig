const std = @import("std");

const Input = @import("shared").Input;
const input_len: usize = @intCast(@import("sdl_bindings").C.SDL_SCANCODE_COUNT);

const ExtraWork = @import("base.zig").ExtraWork;
const Args = @import("../args.zig").Args;
const Stack = @import("shared").Stack.Stack(u64);
const ErrorHandler = @import("../error.zig").Handler;

const AllocatedMem = packed struct {
    start: u64,
    len: u64,
};

const draw_buf_start_w = 512;
const draw_buf_start_h = 256;

pub const Interpreter = struct {
    prg_ptr: usize = 0,
    stack: Stack,
    mem: std.ArrayList(u8),
    allocated_memory_start: u64,
    alloc_table: std.ArrayList(AllocatedMem) = .empty,
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
            .mem = .fromOwnedSlice(try allocator.dupe(u8, mem)),
            .allocated_memory_start = mem.len,
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
        self.mem.deinit(allocator);
        self.alloc_table.deinit(allocator);
        allocator.free(self.draw_buf);
        self.inputs.deinit(allocator);
        self._error_handler._writer.flush() catch {};
        self._error_handler.writeErrorCount();
    }

    pub fn execNextInstruction(self: *@This(), allocator: std.mem.Allocator) !?ExtraWork {
        var extra_work: ?ExtraWork = null;

        switch (self.mem.items[self.prg_ptr]) {
            0x00 => {
                self.prg_ptr -%= 1;
            },
            0x01 => {
                extra_work = .exit;
            },
            0x02 => {
                for (self.draw_buf) |*byte| byte.* = 0;
                extra_work = .update_screen;
            },
            // Truncate has no effect on 64 bit archs but is required to run on 32 bit archs and is safe
            // since you can't have more memory than 2^32-1 memory on 32 bit archs
            0x03 => self.prg_ptr = @truncate(self.stack.pop() catch |err|
                if (err == error.OutOfBounds) {
                    try self._error_handler.handleInterpreterError("Out of bounds of stack", self.mem.items[self.prg_ptr], self.prg_ptr, err);
                    // We return error no matter what because continuing likely wouldn't lead to any more useful errors
                    // and could easily lead to the execution of unwanted code (executing data as code for example)
                    return error.ErrorPrinted;
                } else return err),
            0x04 => {
                extra_work = .toggle_window_size_lock;
            },
            0x05 => {
                extra_work = .match_window_to_resolution;
            },
            0x06 => {
                // u32 is just enough to store u16 * u16
                const collumns = (@as(u32, self.mem.items[self.prg_ptr + 1]) << 8) + self.mem.items[self.prg_ptr + 2];
                const rows = (@as(u32, self.mem.items[self.prg_ptr + 3]) << 8) + self.mem.items[self.prg_ptr + 4];
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
            0x07...0x0A => {
                try self._error_handler.handleInterpreterError("Unimplemented instruction", self.mem.items[self.prg_ptr], self.prg_ptr, error.UnimplementedInstruction);
            },
            0x10 => {
                self.prg_ptr = self.read64BitNumber(self.prg_ptr + 1) -% 1;
            },
            0x11...0x16 => {
                try self._error_handler.handleInterpreterError("Unimplemented instruction", self.mem.items[self.prg_ptr], self.prg_ptr, error.UnimplementedInstruction);
            },
            0x17 => {
                const address = self.read64BitNumber(self.prg_ptr + 1);
                self.prg_ptr += 8;
                try self.stack.push(allocator, self.prg_ptr);
                self.prg_ptr = address -% 1;
            },
            0x20...0x21 => blk: {
                defer self.prg_ptr += 16;
                const ref_ptr = self.read64BitNumber(self.prg_ptr + 1);
                try self.write64BitNumber(ref_ptr, self.mem.items.len);
                // zig fmt: off
                const bytes_to_alloc =
                    if (self.mem.items[self.prg_ptr] == 0x20)
                        self.read64BitNumber(self.prg_ptr + 9)
                    else if (self.mem.items[self.prg_ptr] == 0x21)
                        self.read64BitNumber(self.read64BitNumber(self.prg_ptr + 9))
                    else unreachable;
                // zig fmt: on

                if (bytes_to_alloc == 0) break :blk;

                const old_len = self.mem.items.len;
                try self.mem.resize(allocator, self.mem.items.len + bytes_to_alloc);

                if (self.alloc_table.items.len == 0) {
                    try self.alloc_table.append(allocator, .{ .start = old_len, .len = self.mem.items.len - old_len });
                } else {
                    self.alloc_table.items[self.alloc_table.items.len - 1].len = self.mem.items.len;
                }
            },
            0x22...0x23 => blk: {
                defer self.prg_ptr += 16;
                const free_start = self.read64BitNumber(self.read64BitNumber(self.prg_ptr + 1));
                // zig fmt: off
                const free_len =
                    if (self.mem.items[self.prg_ptr] == 0x22)
                        self.read64BitNumber(self.prg_ptr + 9)
                    else if (self.mem.items[self.prg_ptr] == 0x23)
                        self.read64BitNumber(self.read64BitNumber(self.prg_ptr + 9))
                    else unreachable;
                // zig fmt: on

                if (free_len == 0) break :blk;

                if (self.alloc_table.items.len == 0) {
                    try self._error_handler.handleInterpreterError("Attempt to free non allocated memory detected", self.mem.items[self.prg_ptr], self.prg_ptr, error.InvalidFree);
                    break :blk;
                }

                if (free_start < self.alloc_table.items[0].start) {
                    try self._error_handler.handleInterpreterError("Attempt to free non allocated memory detected", self.mem.items[self.prg_ptr], self.prg_ptr, error.InvalidFree);
                    break :blk;
                }

                var alloc_index: usize = 0;
                while (true) {
                    if (alloc_index >= self.alloc_table.items.len) {
                        try self._error_handler.handleInterpreterError("Attempt to free non allocated memory detected", self.mem.items[self.prg_ptr], self.prg_ptr, error.InvalidFree);
                        break :blk;
                    }
                    const allocation = &self.alloc_table.items[alloc_index];
                    if (free_start < allocation.start + allocation.len) {
                        if (free_start == allocation.start) {
                            if (free_len == allocation.len) {
                                _ = self.alloc_table.orderedRemove(alloc_index);
                                if (self.alloc_table.items.len == 0) {
                                    self.mem.shrinkRetainingCapacity(self.allocated_memory_start);
                                } else {
                                    self.mem.shrinkRetainingCapacity(self.alloc_table.getLast().start + self.alloc_table.getLast().len);
                                }
                            } else if (free_len < allocation.len) {
                                allocation.start = free_start + free_len;
                                allocation.len = allocation.len - free_len;
                            } else {
                                try self._error_handler.handleInterpreterError("Attempt to free non allocated memory detected", self.mem.items[self.prg_ptr], self.prg_ptr, error.InvalidFree);
                                break :blk;
                            }
                        } else {
                            if (free_start + free_len == allocation.start + allocation.len) {
                                if (alloc_index == self.alloc_table.items.len - 1) self.mem.shrinkRetainingCapacity(free_start);
                            } else if (free_start + free_len < allocation.start + allocation.len) {
                                try self.alloc_table.insert(
                                    allocator,
                                    alloc_index + 1,
                                    .{ .start = free_start + free_len, .len = allocation.len - free_len - (free_start - allocation.start) },
                                );
                            } else {
                                try self._error_handler.handleInterpreterError("Attempt to free non allocated memory detected", self.mem.items[self.prg_ptr], self.prg_ptr, error.InvalidFree);
                                break :blk;
                            }
                            allocation.len = free_start - allocation.start;
                        }
                        break;
                    }
                    alloc_index += 1;
                }
            },
            else => try self._error_handler.handleInterpreterError("Unknown instruction", self.mem.items[self.prg_ptr], self.prg_ptr, error.UnknownInstruction),
        }
        self.prg_ptr +%= 1;

        return extra_work;
    }

    fn read64BitNumber(self: *@This(), at: u64) u64 {
        const i: usize = @intCast(at);
        const arr = self.mem.items[i .. i + 8];
        const val = std.mem.bigToNative(u64, std.mem.bytesToValue(u64, arr));
        return val;
    }

    fn write64BitNumber(self: *@This(), at: u64, val: u64) !void {
        if (at >= self.mem.items.len) {
            try self._error_handler.handleInterpreterError("Out of bounds of memory", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
        }
        self.mem.replaceRangeAssumeCapacity(
            at,
            8,
            &std.mem.toBytes(std.mem.nativeToBig(@TypeOf(val), val)),
        );
    }
};
