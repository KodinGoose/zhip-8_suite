const std = @import("std");
const Base = @import("interpreter_base.zig");

pub const Schip11Interpreter = struct {
    base: Base.InterpreterBase,

    /// low_res: 64x32
    /// high_res: 128x64
    res: enum(u1) { low_res, high_res } = .low_res,
    flags_storage: [16]u8 = [1]u8{0} ** 16,

    pub fn execNextInstruction(self: *@This(), allocator: std.mem.Allocator) !?Base.ExtraWork {
        var ret_work: ?Base.ExtraWork = null;
        const cur_byte: Base.Byte = self.base.mem[self.base.prg_ptr];
        const next_byte: Base.Byte = self.base.mem[self.base.prg_ptr + 1];
        self.base.prg_ptr += 2;

        switch (cur_byte.u) {
            0x0 => {
                switch (@as(u8, @bitCast(next_byte))) {
                    0xC0...0xCF => blk: {
                        const N: i32 = @bitCast(@as(u32, next_byte.l));
                        if (next_byte.l == 0) break :blk;
                        var j = self.base.display_h - 1;
                        outer_loop: while (j > 0) : (j -= 1) {
                            for (0..@as(u32, @bitCast(self.base.display_w))) |i| {
                                const index = @as(i32, @intCast(@as(i64, @bitCast(i)))) + j * self.base.display_w;
                                if (index - self.base.display_w * N < 0) break :outer_loop;
                                self.base.display_buffer[@as(u32, @bitCast(index))] = self.base.display_buffer[@as(u32, @bitCast(index - self.base.display_w * N))];
                                self.base.display_buffer[@as(u32, @bitCast(index - self.base.display_w * N))] = 0;
                            }
                        }
                        ret_work = .update_screen;
                    },
                    0xE0 => {
                        for (0..self.base.display_buffer.len) |i| {
                            self.base.display_buffer[i] = 0;
                            ret_work = .update_screen;
                        }
                    },
                    0xEE => blk: {
                        self.base.prg_ptr = self.base.stack.pop() catch |err| {
                            try self.base.error_handler.handleInterpreterError(
                                allocator,
                                "Tried to return from top level function",
                                @bitCast(cur_byte),
                                @bitCast(next_byte),
                                self.base.prg_ptr,
                                err,
                            );
                            break :blk;
                        };
                    },
                    0xFB => {
                        var j: i32 = 0;
                        while (j < self.base.display_h) : (j += 1) {
                            var i = self.base.display_w - 1;
                            while (i >= 4) : (i -= 1) {
                                const index = i + j * self.base.display_w;
                                self.base.display_buffer[@as(u32, @bitCast(index))] = self.base.display_buffer[@as(u32, @bitCast(index - 4))];
                                self.base.display_buffer[@as(u32, @bitCast(index - 4))] = 0;
                            }
                        }
                        ret_work = .update_screen;
                    },
                    0xFC => {
                        var j: i32 = 0;
                        while (j < self.base.display_h) : (j += 1) {
                            var i: i32 = 0;
                            while (i < self.base.display_w - 4) : (i += 1) {
                                const index = i + j * self.base.display_w;
                                self.base.display_buffer[@as(u32, @bitCast(index))] = self.base.display_buffer[@as(u32, @bitCast(index + 4))];
                                self.base.display_buffer[@as(u32, @bitCast(index + 4))] = 0;
                            }
                        }
                        ret_work = .update_screen;
                    },
                    0xFD => ret_work = .exit,
                    0xFE => {
                        self.res = .low_res;
                    },
                    0xFF => {
                        self.res = .high_res;
                    },
                    else => {
                        try self.base.error_handler.handleInterpreterError(
                            allocator,
                            "Unknown instruction",
                            @bitCast(cur_byte),
                            @bitCast(next_byte),
                            self.base.prg_ptr,
                            error.UnknownInstruction,
                        );
                    },
                }
            },
            0x1 => {
                self.base.prg_ptr = Base.getAddress(cur_byte, next_byte);
            },
            0x2 => {
                try self.base.stack.push(allocator, self.base.prg_ptr);
                self.base.prg_ptr = Base.getAddress(cur_byte, next_byte);
            },
            0x3 => {
                if (self.base.registers[cur_byte.l] == @as(u8, @bitCast(next_byte))) self.base.prg_ptr += 2;
            },
            0x4 => {
                if (self.base.registers[cur_byte.l] != @as(u8, @bitCast(next_byte))) self.base.prg_ptr += 2;
            },
            0x5 => {
                if (self.base.registers[cur_byte.l] == self.base.registers[next_byte.u]) self.base.prg_ptr += 2;
            },
            0x6 => {
                self.base.registers[cur_byte.l] = @bitCast(next_byte);
            },
            0x7 => {
                self.base.registers[cur_byte.l] +%= @bitCast(next_byte);
            },
            0x8 => {
                switch (next_byte.l) {
                    0x0 => self.base.registers[cur_byte.l] = self.base.registers[next_byte.u],
                    0x1 => {
                        self.base.registers[cur_byte.l] |= self.base.registers[next_byte.u];
                    },
                    0x2 => {
                        self.base.registers[cur_byte.l] &= self.base.registers[next_byte.u];
                    },
                    0x3 => {
                        self.base.registers[cur_byte.l] ^= self.base.registers[next_byte.u];
                    },
                    0x4 => {
                        const tuple = @addWithOverflow(self.base.registers[cur_byte.l], self.base.registers[next_byte.u]);
                        self.base.registers[cur_byte.l] = tuple[0];
                        self.base.registers[0xF] = tuple[1];
                    },
                    0x5 => {
                        const tuple = @subWithOverflow(self.base.registers[cur_byte.l], self.base.registers[next_byte.u]);
                        self.base.registers[cur_byte.l] = tuple[0];
                        self.base.registers[0xF] = if (tuple[1] == 1) 0 else 1;
                    },
                    0x6 => {
                        // This is commented out because of a weird quirk that schip1.0 and schip1.1 have
                        // self.base.registers[cur_byte.l] = self.base.registers[next_byte.u];
                        const shifted_out_bit = self.base.registers[cur_byte.l] & 0b1;
                        self.base.registers[cur_byte.l] >>= 1;
                        self.base.registers[0xF] = shifted_out_bit;
                    },
                    0x7 => {
                        const tuple = @subWithOverflow(self.base.registers[next_byte.u], self.base.registers[cur_byte.l]);
                        self.base.registers[cur_byte.l] = tuple[0];
                        self.base.registers[0xF] = if (tuple[1] == 1) 0 else 1;
                    },
                    0xE => {
                        // This is commented out because of a weird quirk that schip1.0 and schip1.1 have
                        // self.base.registers[cur_byte.l] = self.base.registers[next_byte.u];
                        const shifted_out_bit = (self.base.registers[cur_byte.l] & 0b10000000) >> 7;
                        self.base.registers[cur_byte.l] <<= 1;
                        self.base.registers[0xF] = shifted_out_bit;
                    },
                    else => {
                        try self.base.error_handler.handleInterpreterError(
                            allocator,
                            "Unknown instruction",
                            @bitCast(cur_byte),
                            @bitCast(next_byte),
                            self.base.prg_ptr,
                            error.UnknownInstruction,
                        );
                    },
                }
            },
            0x9 => {
                if (self.base.registers[cur_byte.l] != self.base.registers[next_byte.u]) self.base.prg_ptr += 2;
            },
            0xA => {
                self.base.address_register = Base.getAddress(cur_byte, next_byte);
            },
            0xB => {
                self.base.prg_ptr = @as(u8, @bitCast(next_byte)) + (@as(usize, cur_byte.l) << 8) + self.base.registers[cur_byte.l];
            },
            0xC => {
                self.base.registers[cur_byte.l] = @as(u8, @intCast(self.base.rng.next() % 256)) | @as(u8, @bitCast(next_byte));
            },
            0xD => {
                const x: i32 = @intCast(self.base.registers[cur_byte.l] % if (self.res == .low_res) @as(u8, 64) else @as(u8, 128));
                const y: i32 = @intCast(self.base.registers[next_byte.u] % if (self.res == .low_res) @as(u8, 32) else @as(u8, 64));
                const w: i32 = if (self.res == .high_res and next_byte.l == 0) 16 else 8;
                const h: i32 = if (self.res == .high_res and next_byte.l == 0) 16 else next_byte.l;
                var wrote_x: i32 = 0;
                var wrote_y: i32 = 0;
                var address = self.base.address_register;

                // Note: According to http://devernay.free.fr/hacks/chip8/C8TECH10.HTM we should be checking for collision
                self.base.registers[0xF] = 0;
                if (self.res == .low_res) {
                    while (wrote_y < h) {
                        const index = x * 2 + wrote_x * 2 + (wrote_y * 2 + y * 2) * self.base.display_w;
                        blk: {
                            if (y * 2 + wrote_y * 2 >= self.base.display_h or x * 2 + wrote_x * 2 >= self.base.display_w) break :blk;
                            const pixel_before_1 = self.base.display_buffer[@as(u32, @bitCast(index))];
                            const pixel_before_2 = self.base.display_buffer[@as(u32, @bitCast(index + 1))];
                            const pixel_before_3 = self.base.display_buffer[@as(u32, @bitCast(index + self.base.display_w))];
                            const pixel_before_4 = self.base.display_buffer[@as(u32, @bitCast(index + self.base.display_w + 1))];
                            const val: u8 = @bitCast(self.base.mem[address]);
                            self.base.display_buffer[@as(u32, @bitCast(index))] ^= @intCast((val >> @as(u3, @intCast(7 - wrote_x))) & 0b1);
                            self.base.display_buffer[@as(u32, @bitCast(index + 1))] ^= @intCast((val >> @as(u3, @intCast(7 - wrote_x))) & 0b1);
                            self.base.display_buffer[@as(u32, @bitCast(index + self.base.display_w))] ^= @intCast((val >> @as(u3, @intCast(7 - wrote_x))) & 0b1);
                            self.base.display_buffer[@as(u32, @bitCast(index + self.base.display_w + 1))] ^= @intCast((val >> @as(u3, @intCast(7 - wrote_x))) & 0b1);
                            if (pixel_before_1 == 1 and self.base.display_buffer[@as(u32, @bitCast(index))] == 0) {
                                self.base.registers[0xF] = 1;
                            } else if (pixel_before_2 == 1 and self.base.display_buffer[@as(u32, @bitCast(index + 1))] == 0) {
                                self.base.registers[0xF] = 1;
                            } else if (pixel_before_3 == 1 and self.base.display_buffer[@as(u32, @bitCast(index + self.base.display_w))] == 0) {
                                self.base.registers[0xF] = 1;
                            } else if (pixel_before_4 == 1 and self.base.display_buffer[@as(u32, @bitCast(index + self.base.display_w + 1))] == 0) {
                                self.base.registers[0xF] = 1;
                            }
                        }
                        wrote_x += 1;
                        if (wrote_x >= w) {
                            wrote_x -= w;
                            wrote_y += 1;
                            address += 1;
                            // Emulating a 16 bit unsigned integer overflowing
                            address %= std.math.pow(@TypeOf(address), 2, 16);
                        }
                    }
                } else if (self.res == .high_res) {
                    var collision_on_current_row = false;
                    while (wrote_y < h) {
                        const index = x + wrote_x + (wrote_y + y) * self.base.display_w;
                        blk: {
                            if (y + wrote_y >= self.base.display_h) {
                                collision_on_current_row = true;
                                break :blk;
                            }
                            if (x + wrote_x >= self.base.display_w) break :blk;
                            const pixel_before = self.base.display_buffer[@as(u32, @bitCast(index))];
                            const val: u8 = @bitCast(self.base.mem[address]);
                            if (wrote_x < 8) {
                                self.base.display_buffer[@as(u32, @bitCast(index))] ^= @intCast((val >> @as(u3, @intCast(7 - wrote_x))) & 0b1);
                            } else {
                                self.base.display_buffer[@as(u32, @bitCast(index))] ^= @intCast((val >> @as(u3, @intCast(15 - wrote_x))) & 0b1);
                            }
                            if (pixel_before == 1 and self.base.display_buffer[@as(u32, @bitCast(index))] == 0) {
                                collision_on_current_row = true;
                            }
                        }
                        wrote_x += 1;
                        if (wrote_x >= w) {
                            wrote_x -= w;
                            wrote_y += 1;
                            address += 1;
                            // Emulating a 16 bit unsigned integer overflowing
                            address %= std.math.pow(@TypeOf(address), 2, 16);
                            if (collision_on_current_row) {
                                collision_on_current_row = false;
                                self.base.registers[0xF] += 1;
                            }
                        } else if (wrote_x == 8) {
                            address += 1;
                            // Emulating a 16 bit unsigned integer overflowing
                            address %= std.math.pow(@TypeOf(address), 2, 16);
                        }
                    }
                }
                ret_work = .update_screen;
            },
            0xE => {
                switch (@as(u8, @bitCast(next_byte))) {
                    0x9E => blk: {
                        if (self.base.registers[cur_byte.l] > 0xF) break :blk;
                        if (self.base.user_inputs.inputs[self.base.registers[cur_byte.l]].down) self.base.prg_ptr += 2;
                    },
                    0xA1 => blk: {
                        if (self.base.registers[cur_byte.l] > 0xF) break :blk;
                        if (!self.base.user_inputs.inputs[self.base.registers[cur_byte.l]].down) self.base.prg_ptr += 2;
                    },
                    else => {
                        try self.base.error_handler.handleInterpreterError(
                            allocator,
                            "Unknown instruction",
                            @bitCast(cur_byte),
                            @bitCast(next_byte),
                            self.base.prg_ptr,
                            error.UnknownInstruction,
                        );
                    },
                }
            },
            0xF => {
                switch (@as(u8, @bitCast(next_byte))) {
                    0x07 => self.base.registers[cur_byte.l] = self.base.delay_timer,
                    0x0A => {
                        // Effectively pause the interpreter
                        self.base.prg_ptr -= 2;
                        for (self.base.user_inputs.inputs, 0..) |input, value| {
                            if (input.released) {
                                self.base.registers[cur_byte.l] = @intCast(value);
                                // effectively unpause the interpreter
                                self.base.prg_ptr += 2;
                                break;
                            }
                        }
                    },
                    0x15 => self.base.delay_timer = self.base.registers[cur_byte.l],
                    0x18 => self.base.sound_timer = self.base.registers[cur_byte.l],
                    0x1E => {
                        self.base.address_register += self.base.registers[cur_byte.l];
                        // Emulating a 16 bit unsigned integer overflowing
                        self.base.address_register %= std.math.pow(usize, 2, 16);
                    },
                    0x29 => {
                        // Note: This only works because the fonts start at 0x0 in the interpreters memory
                        self.base.address_register = self.base.registers[cur_byte.l] * 5;
                    },
                    0x30 => {
                        // Note: This only works because the fonts start at 0x0 in the interpreters memory
                        self.base.address_register = self.base.registers[cur_byte.l] * 10 + 0x50;
                    },
                    0x33 => {
                        var byte = self.base.registers[cur_byte.l];
                        self.base.mem[self.base.address_register + 2] = @bitCast(byte % 10);
                        byte /= 10;
                        self.base.mem[self.base.address_register + 1] = @bitCast(byte % 10);
                        byte /= 10;
                        self.base.mem[self.base.address_register] = @bitCast(byte);
                    },
                    0x55 => {
                        var address_register = self.base.address_register;
                        for (0..@as(usize, cur_byte.l) + 1) |i| {
                            self.base.mem[address_register] = @bitCast(self.base.registers[i]);
                            address_register += 1;
                        }
                    },
                    0x65 => {
                        var address_register = self.base.address_register;
                        for (0..@as(usize, cur_byte.l) + 1) |i| {
                            self.base.registers[i] = @bitCast(self.base.mem[address_register]);
                            address_register += 1;
                        }
                    },
                    0x75 => for (0..@as(usize, cur_byte.l) + 1) |i| {
                        self.flags_storage[i] = @bitCast(self.base.registers[i]);
                    },
                    0x85 => for (0..@as(usize, cur_byte.l) + 1) |i| {
                        self.flags_storage[i] = @bitCast(self.base.registers[i]);
                    },
                    else => {
                        try self.base.error_handler.handleInterpreterError(
                            allocator,
                            "Unknown instruction",
                            @bitCast(cur_byte),
                            @bitCast(next_byte),
                            self.base.prg_ptr,
                            error.UnknownInstruction,
                        );
                    },
                }
            },
        }

        // Emulating a 12 bit integer
        self.base.prg_ptr %= 4096;
        self.base.hertz_counter += 1;
        if (self.base.hertz_counter % 10 == 0) {
            self.base.sound_timer -|= 1;
            self.base.delay_timer -|= 1;
        }
        return ret_work;
    }
};
