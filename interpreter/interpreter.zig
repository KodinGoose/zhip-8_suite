const std = @import("std");
const builtin = @import("builtin");
const Inputs = @import("input").Inputs;
const Stack = @import("stack.zig").Stack(usize);
const ErrorHandler = @import("error.zig").Handler;
const Args = @import("args.zig").Args;

const Byte = packed struct {
    /// Short for lower, shortened because of long code lines
    l: u4,
    /// Short for upper, shortened because of long code lines
    u: u4,
};

/// These are things the interpreter cannot do by itself and must be done by the caller
pub const AdditionalWork = enum(u8) {
    update_screen,
    exit,
};

pub const Interpreter = struct {
    /// Taking inputs is the job of the caller
    user_inputs: Inputs,
    _display_buffer: []u1,
    /// Type is i32 due to compatibility with C
    _display_w: i32,
    /// Type is i32 due to compatibility with C
    _display_h: i32,
    _mem: []Byte,
    _prg_ptr: usize,
    /// Counts down once every 10 hertz
    _sound_timer: u8 = 0,
    /// Counts down once every 10 hertz
    _delay_timer: u8 = 0,
    _hertz_counter: u64 = 0,
    _stack: Stack,
    _registers: [16]u8 = [1]u8{0} ** 16,
    _flags_storage: [16]u8 = [1]u8{0} ** 16,
    _address_register: usize = 0,

    _error_handler: ErrorHandler,
    _rng: std.Random.DefaultPrng,

    /// By passing in "mem" the caller gives up ownership until deinit is called after
    /// which it's once again owned by the caller
    pub fn init(allocator: std.mem.Allocator, mem: []u8, display_w: i32, display_h: i32, args: Args) !@This() {
        const interpreter = Interpreter{
            .user_inputs = try Inputs.init(allocator, 16),
            ._display_buffer = try allocator.alloc(u1, @as(u32, @bitCast(display_w * display_h))),
            ._display_w = display_w,
            ._display_h = display_h,
            ._mem = @ptrCast(mem),
            ._prg_ptr = args.program_start_index,
            ._stack = try Stack.init(allocator, 16),

            ._error_handler = ErrorHandler{ .panic_on_error = args.interpreter_panic_on_error },
            ._rng = std.Random.DefaultPrng.init(@intCast(@as(u128, @bitCast(std.time.nanoTimestamp())))),
        };
        for (0..interpreter._display_buffer.len) |i| {
            interpreter._display_buffer[i] = 0;
        }
        return interpreter;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self._display_buffer);
        self._stack.deinit(allocator);
        self._error_handler.flush() catch {};
        self._error_handler.deinit(allocator);
    }

    pub fn execNextInstruction(self: *@This(), allocator: std.mem.Allocator) !?AdditionalWork {
        var ret_work: ?AdditionalWork = null;

        const cur_byte: Byte = self._mem[self._prg_ptr];
        const next_byte: Byte = self._mem[self._prg_ptr + 1];
        self._prg_ptr += 2;
        switch (cur_byte.u) {
            0x0 => {
                switch (@as(u8, @bitCast(next_byte))) {
                    0xE0 => {
                        for (0..self._display_buffer.len) |i| {
                            self._display_buffer[i] = 0;
                            ret_work = .update_screen;
                        }
                    },
                    0xEE => blk: {
                        self._prg_ptr = self._stack.pop() catch |err| {
                            try self._error_handler.handleInterpreterError(
                                allocator,
                                "Tried to return from top level function",
                                @bitCast(cur_byte),
                                @bitCast(next_byte),
                                self._prg_ptr,
                                err,
                            );
                            break :blk;
                        };
                    },
                    0xFD => {
                        ret_work = .exit;
                    },
                    else => {
                        try self._error_handler.handleInterpreterError(
                            allocator,
                            "Unknown instruction",
                            @bitCast(cur_byte),
                            @bitCast(next_byte),
                            self._prg_ptr,
                            error.UnknownInstruction,
                        );
                    },
                }
            },
            0x1 => {
                self._prg_ptr = getAddress(cur_byte, next_byte);
            },
            0x2 => {
                try self._stack.push(allocator, self._prg_ptr);
                self._prg_ptr = getAddress(cur_byte, next_byte);
            },
            0x3 => {
                if (self._registers[cur_byte.l] == @as(u8, @bitCast(next_byte))) self._prg_ptr += 2;
            },
            0x4 => {
                if (self._registers[cur_byte.l] != @as(u8, @bitCast(next_byte))) self._prg_ptr += 2;
            },
            0x5 => {
                if (self._registers[cur_byte.l] == self._registers[next_byte.u]) self._prg_ptr += 2;
            },
            0x6 => {
                self._registers[cur_byte.l] = @bitCast(next_byte);
            },
            0x7 => {
                self._registers[cur_byte.l] +%= @bitCast(next_byte);
            },
            0x8 => {
                switch (next_byte.l) {
                    0x0 => self._registers[cur_byte.l] = self._registers[next_byte.u],
                    0x1 => {
                        self._registers[cur_byte.l] |= self._registers[next_byte.u];
                        self._registers[0xF] = 0;
                    },
                    0x2 => {
                        self._registers[cur_byte.l] &= self._registers[next_byte.u];
                        self._registers[0xF] = 0;
                    },
                    0x3 => {
                        self._registers[cur_byte.l] ^= self._registers[next_byte.u];
                        self._registers[0xF] = 0;
                    },
                    0x4 => {
                        const tuple = @addWithOverflow(self._registers[cur_byte.l], self._registers[next_byte.u]);
                        self._registers[cur_byte.l] = tuple[0];
                        self._registers[0xF] = tuple[1];
                    },
                    0x5 => {
                        const tuple = @subWithOverflow(self._registers[cur_byte.l], self._registers[next_byte.u]);
                        self._registers[cur_byte.l] = tuple[0];
                        self._registers[0xF] = if (tuple[1] == 1) 0 else 1;
                    },
                    0x6 => {
                        self._registers[cur_byte.l] = self._registers[next_byte.u];
                        const shifted_out_bit = self._registers[cur_byte.l] & 0b1;
                        self._registers[cur_byte.l] >>= 1;
                        self._registers[0xF] = shifted_out_bit;
                    },
                    0x7 => {
                        const tuple = @subWithOverflow(self._registers[next_byte.u], self._registers[cur_byte.l]);
                        self._registers[cur_byte.l] = tuple[0];
                        self._registers[0xF] = if (tuple[1] == 1) 0 else 1;
                    },
                    0xE => {
                        self._registers[cur_byte.l] = self._registers[next_byte.u];
                        const shifted_out_bit = (self._registers[cur_byte.l] & 0b10000000) >> 7;
                        self._registers[cur_byte.l] <<= 1;
                        self._registers[0xF] = shifted_out_bit;
                    },
                    else => {
                        try self._error_handler.handleInterpreterError(
                            allocator,
                            "Unknown instruction",
                            @bitCast(cur_byte),
                            @bitCast(next_byte),
                            self._prg_ptr,
                            error.UnknownInstruction,
                        );
                    },
                }
            },
            0x9 => {
                if (self._registers[cur_byte.l] != self._registers[next_byte.u]) self._prg_ptr += 2;
            },
            0xA => {
                self._address_register = getAddress(cur_byte, next_byte);
            },
            0xB => {
                self._prg_ptr = @as(usize, getAddress(cur_byte, next_byte)) + self._registers[0];
            },
            0xC => {
                self._registers[cur_byte.l] = @as(u8, @intCast(self._rng.next() % 256)) | @as(u8, @bitCast(next_byte));
            },
            0xD => {
                const x: i32 = @intCast(self._registers[cur_byte.l] % @as(u32, @bitCast(self._display_w)));
                const y: i32 = @intCast(self._registers[next_byte.u] % @as(u32, @bitCast(self._display_h)));
                const N: i32 = next_byte.l;
                var wrote_x: i32 = 0;
                var wrote_y: i32 = 0;
                var address = self._address_register;

                self._registers[0xF] = 0;
                while (wrote_y < N) {
                    const index = x + wrote_x + (wrote_y + y) * self._display_w;
                    blk: {
                        if (y + wrote_y >= self._display_h or x + wrote_x >= self._display_w) break :blk;
                        const pixel_before = self._display_buffer[@as(u32, @bitCast(index))];
                        const val: u8 = @bitCast(self._mem[address]);
                        self._display_buffer[@as(u32, @bitCast(index))] ^= @intCast((val >> @as(u3, @intCast(7 - wrote_x))) & 0b1);
                        if (pixel_before == 1 and self._display_buffer[@as(u32, @bitCast(index))] == 0) {
                            self._registers[0xF] = 1;
                        }
                    }
                    wrote_x += 1;
                    if (wrote_x >= 8) {
                        wrote_x -= 8;
                        wrote_y += 1;
                        address += 1;
                        // Emulating a 16 bit unsigned integer overflowing
                        address %= std.math.pow(@TypeOf(address), 2, 16);
                    }
                }
                ret_work = .update_screen;
            },
            0xE => {
                switch (@as(u8, @bitCast(next_byte))) {
                    0x9E => blk: {
                        if (self._registers[cur_byte.l] > 0xF) break :blk;
                        if (self.user_inputs.inputs[self._registers[cur_byte.l]].down) self._prg_ptr += 2;
                    },
                    0xA1 => blk: {
                        if (self._registers[cur_byte.l] > 0xF) break :blk;
                        if (!self.user_inputs.inputs[self._registers[cur_byte.l]].down) self._prg_ptr += 2;
                    },
                    else => {
                        try self._error_handler.handleInterpreterError(
                            allocator,
                            "Unknown instruction",
                            @bitCast(cur_byte),
                            @bitCast(next_byte),
                            self._prg_ptr,
                            error.UnknownInstruction,
                        );
                    },
                }
            },
            0xF => {
                switch (@as(u8, @bitCast(next_byte))) {
                    0x07 => self._registers[cur_byte.l] = self._delay_timer,
                    0x0A => {
                        // Effectively pause the interpreter
                        self._prg_ptr -= 2;
                        for (self.user_inputs.inputs, 0..) |input, value| {
                            if (input.released) {
                                self._registers[cur_byte.l] = @intCast(value);
                                // effectively unpause the interpreter
                                self._prg_ptr += 2;
                                break;
                            }
                        }
                    },
                    0x15 => self._delay_timer = self._registers[cur_byte.l],
                    0x18 => self._sound_timer = self._registers[cur_byte.l],
                    0x1E => {
                        self._address_register += self._registers[cur_byte.l];
                        // Emulating a 16 bit unsigned integer overflowing
                        self._address_register %= std.math.pow(usize, 2, 16);
                    },
                    0x29 => {
                        // Note: This only works because the fonts start at 0x0 in the interpreters memory
                        self._address_register = self._registers[cur_byte.l] * 5;
                    },
                    0x33 => {
                        var byte = self._registers[cur_byte.l];
                        self._mem[self._address_register + 2] = @bitCast(byte % 10);
                        byte /= 10;
                        self._mem[self._address_register + 1] = @bitCast(byte % 10);
                        byte /= 10;
                        self._mem[self._address_register] = @bitCast(byte);
                    },
                    0x55 => {
                        for (0..@as(usize, cur_byte.l) + 1) |i| {
                            self._mem[self._address_register] = @bitCast(self._registers[i]);
                            self._address_register += 1;
                        }
                    },
                    0x65 => {
                        for (0..@as(usize, cur_byte.l) + 1) |i| {
                            self._registers[i] = @bitCast(self._mem[self._address_register]);
                            self._address_register += 1;
                        }
                    },
                    0x75 => {
                        for (0..@as(usize, cur_byte.l + 1)) |i| {
                            self._flags_storage[i] = self._registers[i];
                            self._address_register += 1;
                        }
                    },
                    0x85 => {
                        for (0..@as(usize, cur_byte.l + 1)) |i| {
                            self._registers[i] = self._flags_storage[i];
                            self._address_register += 1;
                        }
                    },
                    else => {
                        try self._error_handler.handleInterpreterError(
                            allocator,
                            "Unknown instruction",
                            @bitCast(cur_byte),
                            @bitCast(next_byte),
                            self._prg_ptr,
                            error.UnknownInstruction,
                        );
                    },
                }
            },
        }

        // Emulating a 12 bit integer
        self._prg_ptr %= 4096;
        self._hertz_counter += 1;
        if (self._hertz_counter % 10 == 0) {
            self._sound_timer -|= 1;
            self._delay_timer -|= 1;
        }
        return ret_work;
    }
};

fn getAddress(cur_byte: Byte, next_byte: Byte) u12 {
    return (@as(u12, cur_byte.l) << 8) + @as(u8, @bitCast(next_byte));
}
