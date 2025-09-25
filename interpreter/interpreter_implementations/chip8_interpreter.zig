const std = @import("std");
const Base = @import("interpreter_base.zig");

pub const Chip8Interpreter = struct {
    base: Base.InterpreterBase,

    pub fn execNextInstruction(self: *@This(), allocator: std.mem.Allocator) !?Base.ExtraWork {
        var ret_work: ?Base.ExtraWork = null;

        const cur_byte: Base.Byte = self.base.mem[self.base.prg_ptr];
        const next_byte: Base.Byte = self.base.mem[self.base.prg_ptr + 1];
        self.base.prg_ptr += 2;
        switch (cur_byte.u) {
            0x0 => {
                switch (@as(u8, @bitCast(next_byte))) {
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
                        self.base.registers[0xF] = 0;
                    },
                    0x2 => {
                        self.base.registers[cur_byte.l] &= self.base.registers[next_byte.u];
                        self.base.registers[0xF] = 0;
                    },
                    0x3 => {
                        self.base.registers[cur_byte.l] ^= self.base.registers[next_byte.u];
                        self.base.registers[0xF] = 0;
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
                        self.base.registers[cur_byte.l] = self.base.registers[next_byte.u];
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
                        self.base.registers[cur_byte.l] = self.base.registers[next_byte.u];
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
                self.base.prg_ptr = @as(usize, Base.getAddress(cur_byte, next_byte)) + self.base.registers[0];
            },
            0xC => {
                self.base.registers[cur_byte.l] = @as(u8, @intCast(self.base.rng.next() % 256)) | @as(u8, @bitCast(next_byte));
            },
            0xD => {
                const x: i32 = @intCast(self.base.registers[cur_byte.l] % @as(u32, @bitCast(self.base.display_w)));
                const y: i32 = @intCast(self.base.registers[next_byte.u] % @as(u32, @bitCast(self.base.display_h)));
                const N: i32 = next_byte.l;
                var wrote_x: i32 = 0;
                var wrote_y: i32 = 0;
                var address = self.base.address_register;

                // Note: According to http://devernay.free.fr/hacks/chip8/C8TECH10.HTM we should be checking for collision
                self.base.registers[0xF] = 0;
                while (wrote_y < N) {
                    const index = x + wrote_x + (wrote_y + y) * self.base.display_w;
                    blk: {
                        if (y + wrote_y >= self.base.display_h or x + wrote_x >= self.base.display_w) break :blk;
                        const pixel_before = self.base.display_buffer[@as(u32, @bitCast(index))];
                        const val: u8 = @bitCast(self.base.mem[address]);
                        self.base.display_buffer[@as(u32, @bitCast(index))] ^= @intCast((val >> @as(u3, @intCast(7 - wrote_x))) & 0b1);
                        if (pixel_before == 1 and self.base.display_buffer[@as(u32, @bitCast(index))] == 0) {
                            self.base.registers[0xF] = 1;
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
                    0x33 => {
                        var byte = self.base.registers[cur_byte.l];
                        self.base.mem[self.base.address_register + 2] = @bitCast(byte % 10);
                        byte /= 10;
                        self.base.mem[self.base.address_register + 1] = @bitCast(byte % 10);
                        byte /= 10;
                        self.base.mem[self.base.address_register] = @bitCast(byte);
                    },
                    0x55 => {
                        for (0..@as(usize, cur_byte.l) + 1) |i| {
                            self.base.mem[self.base.address_register] = @bitCast(self.base.registers[i]);
                            self.base.address_register += 1;
                        }
                    },
                    0x65 => {
                        for (0..@as(usize, cur_byte.l) + 1) |i| {
                            self.base.registers[i] = @bitCast(self.base.mem[self.base.address_register]);
                            self.base.address_register += 1;
                        }
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
