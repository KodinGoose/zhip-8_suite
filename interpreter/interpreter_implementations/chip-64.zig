const std = @import("std");
const builtin = @import("builtin");

const sdl = @import("sdl_bindings");

const Input = @import("shared").Input;
const input_len: usize = @intCast(sdl.C.SDL_SCANCODE_COUNT);

const ExtraWork = @import("base.zig").ExtraWork;
const Args = @import("../args.zig").Args;
const Stack = @import("shared").Stack.Stack(u64);
const ErrorHandler = @import("../error.zig").Handler;
const BigInt = @import("shared").BigInt;

const AllocatedMem = packed struct {
    start: u64,
    len: u64,
};

const draw_start_start_w = 512;
const draw_surface_start_h = 256;

pub const Interpreter = struct {
    prg_ptr: usize = 0,
    stack: Stack,
    mem: std.ArrayList(u8),
    allocated_memory_start: u64,
    alloc_table: std.ArrayList(AllocatedMem) = .empty,
    draw_surface: *sdl.render.Surface,
    inputs: Input,
    rand_gen: std.Random.DefaultPrng,
    sound_timer: u8 = 0,
    hertz_counter: usize = 0,
    _error_handler: ErrorHandler,
    _rand_gen: std.Random.DefaultPrng,

    /// mem includes program code
    /// mem in unmodified
    pub fn init(allocator: std.mem.Allocator, mem: []u8, args: Args, err_writer: *std.Io.Writer) !@This() {
        return Interpreter{
            .prg_ptr = args.program_start_index orelse 0,
            .stack = try .init(allocator, 16),
            .mem = .fromOwnedSlice(try allocator.dupe(u8, mem)),
            .allocated_memory_start = mem.len,
            .draw_surface = try .init(draw_start_start_w, draw_surface_start_h, .rgba8888),
            .inputs = try .init(allocator, input_len),
            .rand_gen = .init(@truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))),
            ._error_handler = .{
                ._writer = err_writer,
                ._panic_on_error = args.interpreter_panic_on_error,
            },
            ._rand_gen = .init(@truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))),
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (self.alloc_table.items) |allocation| {
            self._error_handler._writer.print("Memory leaked, start: 0x{x}, len: 0x{x}\n", .{ allocation.start, allocation.len }) catch {};
        }

        self.stack.deinit(allocator);
        self.mem.deinit(allocator);
        self.alloc_table.deinit(allocator);
        self.draw_surface.deinit();
        self.inputs.deinit(allocator);
        self._error_handler.writeErrorCount();
        self._error_handler._writer.flush() catch {};
    }

    pub fn execNextInstruction(self: *@This(), allocator: std.mem.Allocator) !?ExtraWork {
        var extra_work: ?ExtraWork = null;

        switch (self.mem.items[self.prg_ptr]) {
            0x00 => {
                self.prg_ptr -%= 1;
                extra_work = .halt;
            },
            0x01 => {
                extra_work = .exit;
            },
            0x02 => {
                try self.draw_surface.clearSurface(.{ .r = 0, .g = 0, .b = 0, .a = 0 });
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
                const new_w = (@as(u32, self.mem.items[self.prg_ptr + 1]) << 8) + self.mem.items[self.prg_ptr + 2];
                const new_h = (@as(u32, self.mem.items[self.prg_ptr + 3]) << 8) + self.mem.items[self.prg_ptr + 4];
                self.draw_surface.deinit();
                self.draw_surface = try sdl.render.Surface.init(@bitCast(new_w), @bitCast(new_h), .rgba8888);
                try self.draw_surface.clearSurface(.{ .r = 0, .g = 0, .b = 0, .a = 0 });
                self.prg_ptr +%= 4;
                extra_work = .resolution_changed;
            },
            0x10 => {
                self.prg_ptr = self.read64BitNumber(self.prg_ptr + 1) -% 1;
            },
            0x11...0x16 => {
                var is_true = false;
                const bytes = self.readNumber(u16, self.prg_ptr + 9);
                const var_1_ref = self.read64BitNumber(self.prg_ptr + 11);
                const var_2_ref = self.read64BitNumber(self.prg_ptr + 19);

                var var_1 = BigInt{ .array = self.mem.items[var_1_ref .. var_1_ref + bytes] };
                var_1.reverseByteOrder();
                defer var_1.reverseByteOrder();
                var var_2 = BigInt{ .array = self.mem.items[var_2_ref .. var_2_ref + bytes] };
                var_2.reverseByteOrder();
                defer var_2.reverseByteOrder();

                switch (self.mem.items[self.prg_ptr]) {
                    0x11 => {
                        if (var_1.isLessThan(var_2)) is_true = true;
                    },
                    0x12 => {
                        if (var_1.isLessThanEqual(var_2)) is_true = true;
                    },
                    0x13 => {
                        if (var_2.isLessThan(var_1)) is_true = true;
                    },
                    0x14 => {
                        if (var_2.isLessThanEqual(var_1)) is_true = true;
                    },
                    0x15 => {
                        if (std.mem.eql(u8, var_1.array, var_2.array)) is_true = true;
                    },
                    0x16 => {
                        if (!std.mem.eql(u8, var_1.array, var_2.array)) is_true = true;
                    },
                    else => unreachable,
                }

                if (is_true)
                    self.prg_ptr = self.read64BitNumber(self.prg_ptr + 1) -% 1
                else {
                    // 8 + 2 + 8 + 8
                    self.prg_ptr += 26;
                }
            },
            0x17 => {
                try self.stack.push(allocator, self.prg_ptr + 8);
                self.prg_ptr = self.read64BitNumber(self.prg_ptr + 1) -% 1;
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
            0x30...0x31 => {
                const bytes = self.readNumber(u16, self.prg_ptr + 1);
                defer self.prg_ptr += 2;
                const to_set_ref = self.read64BitNumber(self.prg_ptr + 3);
                defer self.prg_ptr += 8;
                if (to_set_ref >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }
                if (self.mem.items[self.prg_ptr] == 0x30) {
                    @memmove(self.mem.items[to_set_ref .. to_set_ref + bytes], self.mem.items[self.prg_ptr + 11 .. self.prg_ptr + 11 + bytes]);
                    self.prg_ptr += bytes;
                } else {
                    const set_to_ref = self.read64BitNumber(self.prg_ptr + 11);
                    @memmove(self.mem.items[to_set_ref .. to_set_ref + bytes], self.mem.items[set_to_ref .. set_to_ref + bytes]);
                    self.prg_ptr += 8;
                }
            },
            0x40...0x49 => {
                const bytes = self.readNumber(u16, self.prg_ptr + 1);
                defer self.prg_ptr += 2;
                const to_change_ref = self.read64BitNumber(self.prg_ptr + 3);
                defer self.prg_ptr += 8;
                if (to_change_ref >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory (first arg)", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }

                const change_with_ref =
                    if (self.mem.items[self.prg_ptr] % 2 == 0)
                        self.prg_ptr + 11
                    else
                        self.read64BitNumber(self.prg_ptr + 11);
                defer self.prg_ptr += if (self.mem.items[self.prg_ptr] % 2 == 0) bytes else 8;
                if (change_with_ref >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory (second arg)", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }

                var to_change_int = BigInt{ .array = self.mem.items[to_change_ref .. to_change_ref + bytes] };
                to_change_int.reverseByteOrder();
                defer to_change_int.reverseByteOrder();

                var change_with_int = BigInt{ .array = self.mem.items[change_with_ref .. change_with_ref + bytes] };
                change_with_int.reverseByteOrder();
                defer change_with_int.reverseByteOrder();

                switch (self.mem.items[self.prg_ptr]) {
                    0x40...0x41 => _ = to_change_int.addInPlace(change_with_int),
                    0x42...0x43 => _ = to_change_int.subInPlace(change_with_int),
                    0x44...0x45 => _ = try to_change_int.mulInPlace(change_with_int, allocator),
                    0x46...0x47 => _ = try to_change_int.divInPlace(change_with_int, allocator),
                    0x48...0x49 => _ = try to_change_int.modInPlace(change_with_int, allocator),
                    else => unreachable,
                }
            },
            0x50...0x53 => {
                const bytes = self.readNumber(u16, self.prg_ptr + 1);
                defer self.prg_ptr += 2;
                const to_shift_ref = self.read64BitNumber(self.prg_ptr + 3);
                defer self.prg_ptr += 8;
                if (to_shift_ref >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }
                const shift_by_ref = self.prg_ptr + 11;
                defer self.prg_ptr += 3;

                var to_shift_int = BigInt{ .array = self.mem.items[to_shift_ref .. to_shift_ref + bytes] };
                to_shift_int.reverseByteOrder();
                defer to_shift_int.reverseByteOrder();

                // TODO: Somehow eliminate this allocation
                var shift_by_int = try BigInt.init(allocator, 3);
                defer shift_by_int.deinit(allocator);
                shift_by_int.readBigEndian(self.mem.items[shift_by_ref .. shift_by_ref + 3]);
                // This is stupid
                try shift_by_int.setByteLength(bytes, allocator);

                switch (self.mem.items[self.prg_ptr]) {
                    0x50 => to_shift_int.leftShiftInPlace(shift_by_int),
                    0x51 => to_shift_int.leftShiftInPlaceSaturate(shift_by_int),
                    0x52 => to_shift_int.rightShiftInPlace(shift_by_int),
                    0x53 => to_shift_int.rightShiftInPlaceSaturate(shift_by_int),
                    else => unreachable,
                }
            },
            0x54...0x59 => {
                const bytes = self.readNumber(u16, self.prg_ptr + 1);
                defer self.prg_ptr += 2;
                const to_change_ref = self.read64BitNumber(self.prg_ptr + 3);
                defer self.prg_ptr += 8;
                if (to_change_ref >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory (first arg)", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }

                const change_with_ref =
                    if (self.mem.items[self.prg_ptr] % 2 == 0)
                        self.prg_ptr + 11
                    else
                        self.read64BitNumber(self.prg_ptr + 11);
                defer self.prg_ptr += if (self.mem.items[self.prg_ptr] % 2 == 0) bytes else 8;
                if (change_with_ref >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory (second arg)", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }

                var to_change_int = BigInt{ .array = self.mem.items[to_change_ref .. to_change_ref + bytes] };
                to_change_int.reverseByteOrder();
                defer to_change_int.reverseByteOrder();

                var change_with_int = BigInt{ .array = self.mem.items[change_with_ref .. change_with_ref + bytes] };
                change_with_int.reverseByteOrder();
                defer change_with_int.reverseByteOrder();

                switch (self.mem.items[self.prg_ptr]) {
                    0x54...0x55 => _ = to_change_int.bitwiseAndInPlace(change_with_int),
                    0x56...0x57 => _ = to_change_int.bitwiseOrInPlace(change_with_int),
                    0x58...0x59 => _ = to_change_int.bitwiseXorInPlace(change_with_int),
                    else => unreachable,
                }
            },
            0x5A => {
                const bytes = self.readNumber(u16, self.prg_ptr + 1);
                defer self.prg_ptr += 2;
                const to_not_ref = self.read64BitNumber(self.prg_ptr + 3);
                defer self.prg_ptr += 8;
                if (to_not_ref >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }

                var to_not_int = BigInt{ .array = self.mem.items[to_not_ref .. to_not_ref + bytes] };
                to_not_int.reverseByteOrder();
                defer to_not_int.reverseByteOrder();

                to_not_int.bitwiseNotInPlace();
            },
            0x5B => {
                const bytes = self.readNumber(u16, self.prg_ptr + 1);
                defer self.prg_ptr += 2;
                const to_rand_ref = self.read64BitNumber(self.prg_ptr + 3);
                defer self.prg_ptr += 8;
                if (to_rand_ref >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }

                var to_rand_int = BigInt{ .array = self.mem.items[to_rand_ref .. to_rand_ref + bytes] };
                to_rand_int.reverseByteOrder();
                defer to_rand_int.reverseByteOrder();

                for (0..bytes / 8) |i| {
                    const rand_bytes: [8]u8 = @bitCast(self.rand_gen.next());
                    for (i * 8..i * 8 + 8, 0..) |j, k| {
                        to_rand_int.array[j] = rand_bytes[k];
                    }
                }
                if (bytes % 8 != 0) {
                    const rand_bytes: [8]u8 = @bitCast(self.rand_gen.next());
                    for (to_rand_int.array.len / 8 * 8..to_rand_int.array.len, 0..) |j, k| {
                        to_rand_int.array[j] = rand_bytes[k];
                    }
                }
            },
            0x60...0x63 => blk: {
                const key = self.readNumber(u16, self.prg_ptr + 1);
                const jump_address = self.readNumber(u64, self.prg_ptr + 3);

                if (key <= self.inputs.inputs.len) {
                    if (self.inputs.inputs[key].down) {
                        if (self.mem.items[self.prg_ptr] == 0x61 or self.mem.items[self.prg_ptr] == 0x63)
                            try self.stack.push(allocator, self.prg_ptr);

                        self.prg_ptr = jump_address -% 1;
                        break :blk;
                    }

                    if (self.mem.items[self.prg_ptr] == 0x62 or self.mem.items[self.prg_ptr] == 0x63) {
                        self.prg_ptr -%= 1;
                        break :blk;
                    }
                } else {
                    try self._error_handler.handleInterpreterError("Key out of range of possible inputs", self.mem.items[self.prg_ptr], self.prg_ptr, error.NonExistentKey);
                }

                // 2 + 8
                self.prg_ptr +%= 10;
            },
            0x64...0x67 => blk: {
                const key = self.readNumber(u16, self.prg_ptr + 1);
                const jump_address = self.readNumber(u64, self.prg_ptr + 3);

                if (key < self.inputs.inputs.len) {
                    if (!self.inputs.inputs[key].down) {
                        if (self.mem.items[self.prg_ptr] == 0x65 or self.mem.items[self.prg_ptr] == 0x67)
                            try self.stack.push(allocator, self.prg_ptr);

                        self.prg_ptr = jump_address -% 1;
                        break :blk;
                    }

                    if (self.mem.items[self.prg_ptr] == 0x66 or self.mem.items[self.prg_ptr] == 0x67) {
                        self.prg_ptr -%= 1;
                        break :blk;
                    }
                } else {
                    try self._error_handler.handleInterpreterError("Key out of range of possible inputs", self.mem.items[self.prg_ptr], self.prg_ptr, error.NonExistentKey);
                }

                // 2 + 8
                self.prg_ptr +%= 10;
            },
            0x70 => {
                const sprite_w: usize = self.readNumber(u16, self.prg_ptr + 1);
                self.prg_ptr += 2;
                const sprite_h: usize = self.readNumber(u16, self.prg_ptr + 1);
                self.prg_ptr += 2;
                const X: i32 = @bitCast(self.readNumber(u32, self.read64BitNumber(self.prg_ptr + 1)));
                self.prg_ptr += 8;
                const Y: i32 = @bitCast(self.readNumber(u32, self.read64BitNumber(self.prg_ptr + 1)));
                self.prg_ptr += 8;
                const pixel_data_location = self.read64BitNumber(self.prg_ptr + 1);
                self.prg_ptr += 8;

                if (pixel_data_location + (sprite_w * sprite_h) >= self.mem.items.len) {
                    try self._error_handler.handleInterpreterError("Out of bounds of memory", self.mem.items[self.prg_ptr], self.prg_ptr, error.OutOfBounds);
                    return error.ErrorPrinted;
                }

                var pixels = try allocator.dupe(u8, self.mem.items[pixel_data_location .. pixel_data_location + sprite_w * 4 * sprite_h]);
                defer allocator.free(pixels);
                if (builtin.cpu.arch.endian() == .little) {
                    var i: usize = 0;
                    while (i < pixels.len) : (i += 4) {
                        const tmp1 = pixels[i + 0];
                        pixels[i + 0] = pixels[i + 3];
                        pixels[i + 3] = tmp1;
                        const tmp2 = pixels[i + 1];
                        pixels[i + 1] = pixels[i + 2];
                        pixels[i + 2] = tmp2;
                    }
                }

                const sprite = try sdl.render.Surface.initFrom(
                    @bitCast(@as(u32, @intCast(sprite_w))),
                    @bitCast(@as(u32, @intCast(sprite_h))),
                    .rgba8888,
                    pixels,
                    @bitCast(@as(u32, @intCast(sprite_w * 4))),
                );
                defer sprite.deinit();
                std.debug.assert(pixels.len == sprite.pitch * @as(i32, @bitCast(@as(u32, @intCast(sprite_h)))));

                try self.draw_surface.blitSurface(sprite, X, Y);

                extra_work = .update_screen;
            },
            0x80 => {
                const time_ref: usize = self.read64BitNumber(self.prg_ptr + 1);
                self.prg_ptr += 8;
                const time_bytes: [16]u8 = @bitCast(std.mem.nativeToBig(i128, std.time.nanoTimestamp()));
                for (self.mem.items[time_ref .. time_ref + 16], time_bytes) |*byte, time_byte| {
                    byte.* = time_byte;
                }
            },
            0x81 => {
                defer self.prg_ptr += 1;
                if (self.mem.items[self.prg_ptr + 1] == 0) {
                    extra_work = .disable_auto_sleep;
                } else if (self.mem.items[self.prg_ptr + 1] == 1) {
                    extra_work = .enable_auto_sleep;
                } else {
                    try self._error_handler.handleInterpreterError("Invalid argument", self.mem.items[self.prg_ptr], self.prg_ptr, error.InvalidArgument);
                }
            },
            0x82...0x83 => {
                const sleep_for_ref =
                    if (self.mem.items[self.prg_ptr] == 0x82)
                        self.prg_ptr + 1
                    else
                        self.read64BitNumber(self.prg_ptr + 1);
                self.prg_ptr += 8;

                const sleep_for: u64 = self.read64BitNumber(sleep_for_ref);

                std.Thread.sleep(sleep_for);
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

    fn readNumber(self: *@This(), T: type, at: u64) T {
        const i: usize = @intCast(at);
        const arr = self.mem.items[i .. i + (std.math.divCeil(u16, @typeInfo(T).int.bits, 8) catch unreachable)];
        const val = std.mem.bigToNative(T, std.mem.bytesToValue(T, arr));
        return val;
    }
};
