//! This file contains abstractions for the different interoreters

const std = @import("std");
const Args = @import("args.zig");
const ExtraWork = @import("actual_interpreters/interpreter_base.zig").ExtraWork;
const InterpreterBase = @import("actual_interpreters/interpreter_base.zig").InterpreterBase;
const Chip8Interpreter = @import("actual_interpreters/chip8_interpreter.zig").Chip8Interpreter;
const Schip10Interpreter = @import("actual_interpreters/schip1.0_interpreter.zig").Schip10Interpreter;
const Schip11Interpreter = @import("actual_interpreters/schip1.1_interpreter.zig").Schip11Interpreter;
const SchipModernInterpreter = @import("actual_interpreters/schip-modern_interpreter.zig").SchipModernInterpreter;

const InterpreterTypes = union {
    chip8: Chip8Interpreter,
    schip1_0: Schip10Interpreter,
    schip1_1: Schip11Interpreter,
    schip_modern: SchipModernInterpreter,
};

pub const Interpreter = struct {
    _real_interpreter: InterpreterTypes,
    _tag: Args.Build,

    pub fn init(allocator: std.mem.Allocator, mem: []u8, args: Args.Args) !@This() {
        return .{
            ._real_interpreter = switch (args.build) {
                .chip_8 => InterpreterTypes{ .chip8 = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32) } },
                .schip1_0 => InterpreterTypes{ .schip1_0 = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32) } },
                .schip1_1 => InterpreterTypes{ .schip1_1 = .{ .base = try InterpreterBase.init(allocator, mem, args, 128, 64) } },
                .schip_modern => InterpreterTypes{ .schip_modern = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32) } },
            },
            ._tag = args.build,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self._tag) {
            .chip_8 => self._real_interpreter.chip8.base.deinit(allocator),
            .schip1_0 => self._real_interpreter.schip1_0.base.deinit(allocator),
            .schip1_1 => self._real_interpreter.schip1_1.base.deinit(allocator),
            .schip_modern => self._real_interpreter.schip_modern.base.deinit(allocator),
        }
    }

    /// This function is used to get the base of the current interpreter
    /// This is not a copy of the base, it is the base itself
    pub fn getBase(self: *@This()) *InterpreterBase {
        return &switch (self._tag) {
            .chip_8 => self._real_interpreter.chip8.base,
            .schip1_0 => self._real_interpreter.schip1_0.base,
            .schip1_1 => self._real_interpreter.schip1_1.base,
            .schip_modern => self._real_interpreter.schip_modern.base,
        };
    }

    pub fn execNextIntstruction(self: *@This(), allocator: std.mem.Allocator) !?ExtraWork {
        return switch (self._tag) {
            .chip_8 => self._real_interpreter.chip8.execNextInstruction(allocator),
            .schip1_0 => self._real_interpreter.schip1_0.execNextInstruction(allocator),
            .schip1_1 => self._real_interpreter.schip1_1.execNextInstruction(allocator),
            .schip_modern => self._real_interpreter.schip_modern.execNextInstruction(allocator),
        };
    }
};
