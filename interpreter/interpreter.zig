//! This file contains abstractions for the different interoreters

const std = @import("std");
const Args = @import("args.zig");
const ExtraWork = @import("interpreter_implementation/interpreter_base.zig").ExtraWork;
// const InterpreterBase = @import("interpreter_implementations/interpreter_base.zig").InterpreterBase;
// const Chip8Interpreter = @import("interpreter_implementations/chip8.zig").Interpreter;
// const Schip10Interpreter = @import("interpreter_implementations/schip1.0.zig").Interpreter;
// const Schip11Interpreter = @import("interpreter_implementations/schip1.1.zig").Interpreter;
// const SchipModernInterpreter = @import("interpreter_implementations/schip-modern.zig").Interpreter;
const Chip64Interpreter = @import("interpreter_implementations/chip-64.zig").Interpreter;

const InterpreterTypes = union {
    // chip8: Chip8Interpreter,
    // schip1_0: Schip10Interpreter,
    // schip1_1: Schip11Interpreter,
    // schip_modern: SchipModernInterpreter,
    chip_64: Chip64Interpreter,
};

pub const Interpreter = struct {
    _real_interpreter: InterpreterTypes,
    _tag: Args.Build,

    pub fn init(allocator: std.mem.Allocator, mem: []u8, args: Args.Args) !@This() {
        return .{
            ._real_interpreter = switch (args.build) {

                // .chip_8 => InterpreterTypes{ .chip8 = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32) } },
                // .schip1_0 => InterpreterTypes{ .schip1_0 = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32) } },
                // .schip1_1 => InterpreterTypes{ .schip1_1 = .{ .base = try InterpreterBase.init(allocator, mem, args, 128, 64) } },
                // .schip_modern => InterpreterTypes{ .schip_modern = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32) } },
                .chip_64 => InterpreterTypes{ .chip_64 = Chip64Interpreter.init(allocator, mem, args) },
            },
            ._tag = args.build,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self._tag) {
            // .chip_8 => self._real_interpreter.chip8.base.deinit(allocator),
            // .schip1_0 => self._real_interpreter.schip1_0.base.deinit(allocator),
            // .schip1_1 => self._real_interpreter.schip1_1.base.deinit(allocator),
            // .schip_modern => self._real_interpreter.schip_modern.base.deinit(allocator),
            .chip_64 => self._real_interpreter.chip_64.deinit(allocator),
        }
    }

    // /// This function is used to get the base of the current interpreter
    // /// This is not a copy of the base, it is the base itself
    // pub fn getBase(self: *@This()) *InterpreterBase {
    //     return &switch (self._tag) {
    //         // .chip_8 => self._real_interpreter.chip8.base,
    //         // .schip1_0 => self._real_interpreter.schip1_0.base,
    //         // .schip1_1 => self._real_interpreter.schip1_1.base,
    //         // .schip_modern => self._real_interpreter.schip_modern.base,
    //         .chip_64 => unreachable,
    //     };
    // }

    pub fn execNextIntstruction(self: *@This(), allocator: std.mem.Allocator) !?ExtraWork {
        return switch (self._tag) {
            // .chip_8 => self._real_interpreter.chip8.execNextInstruction(allocator),
            // .schip1_0 => self._real_interpreter.schip1_0.execNextInstruction(allocator),
            // .schip1_1 => self._real_interpreter.schip1_1.execNextInstruction(allocator),
            // .schip_modern => self._real_interpreter.schip_modern.execNextInstruction(allocator),
            .chip_64 => self._real_interpreter.chip_64.execNextInstruction(allocator),
        };
    }
};
