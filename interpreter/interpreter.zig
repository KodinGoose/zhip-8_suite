//! This file contains abstractions for the different interoreters

const std = @import("std");

const Surface = @import("sdl_bindings").render.Surface;

const Inputs = @import("shared").Input;

const Args = @import("args.zig");
const ExtraWork = @import("interpreter_implementations/base.zig").ExtraWork;
const InterpreterBase = @import("interpreter_implementations/base.zig").InterpreterBase;
const Chip8Interpreter = @import("interpreter_implementations/chip8.zig").Interpreter;
// const Schip10Interpreter = @import("interpreter_implementations/schip1.0.zig").Interpreter;
// const Schip11Interpreter = @import("interpreter_implementations/schip1.1.zig").Interpreter;
// const SchipModernInterpreter = @import("interpreter_implementations/schip-modern.zig").Interpreter;
const Chip64Interpreter = @import("interpreter_implementations/chip-64.zig").Interpreter;

const InterpreterTypes = union {
    chip8: Chip8Interpreter,
    // schip1_0: Schip10Interpreter,
    // schip1_1: Schip11Interpreter,
    // schip_modern: SchipModernInterpreter,
    chip_64: Chip64Interpreter,
};

pub const Interpreter = struct {
    _real_interpreter: InterpreterTypes,
    _tag: Args.Build,

    pub fn init(allocator: std.mem.Allocator, mem: []u8, args: Args.Args, err_writer: *std.Io.Writer) !@This() {
        return .{
            ._real_interpreter = switch (args.build) {
                .chip_8 => InterpreterTypes{ .chip8 = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32, err_writer) } },
                // .schip1_0 => InterpreterTypes{ .schip1_0 = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32, err_writer) } },
                // .schip1_1 => InterpreterTypes{ .schip1_1 = .{ .base = try InterpreterBase.init(allocator, mem, args, 128, 64, err_writer) } },
                // .schip_modern => InterpreterTypes{ .schip_modern = .{ .base = try InterpreterBase.init(allocator, mem, args, 64, 32, err_writer) } },
                .chip_64 => InterpreterTypes{ .chip_64 = try Chip64Interpreter.init(allocator, mem, args, err_writer) },
                // temp code until I get back the other interpreter implementations
                else => unreachable,
            },
            ._tag = args.build,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self._tag) {
            .chip_8 => self._real_interpreter.chip8.base.deinit(allocator),
            // .schip1_0 => self._real_interpreter.schip1_0.base.deinit(allocator),
            // .schip1_1 => self._real_interpreter.schip1_1.base.deinit(allocator),
            // .schip_modern => self._real_interpreter.schip_modern.base.deinit(allocator),
            .chip_64 => self._real_interpreter.chip_64.deinit(allocator),
            // temp code until I get back the other interpreter implementations
            else => unreachable,
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

    pub fn getProgramPointer(self: *@This()) *usize {
        return switch (self._tag) {
            .chip_8 => &self._real_interpreter.chip8.base.prg_ptr,
            // .schip1_0 => &self._real_interpreter.schip1_0.base.prg_ptr,
            // .schip1_1 => &self._real_interpreter.schip1_1.base.prg_ptr,
            // .schip_modern => &self._real_interpreter.schip_modern.base.prg_ptr,
            .chip_64 => &self._real_interpreter.chip_64.prg_ptr,
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }

    /// LEGACY
    pub fn getDrawBuffer(self: *@This()) []u1 {
        return switch (self._tag) {
            .chip_8 => self._real_interpreter.chip8.base.draw_buf,
            // .schip1_0 => self._real_interpreter.schip1_0.base.draw_buf,
            // .schip1_1 => self._real_interpreter.schip1_1.base.draw_buf,
            // .schip_modern => self._real_interpreter.schip_modern.base.draw_buf,
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }

    pub fn getDrawSurface(self: *@This()) *Surface {
        return switch (self._tag) {
            // .chip_8 => self._real_interpreter.chip8.base.draw_surface,
            // .schip1_0 => self._real_interpreter.schip1_0.base.draw_surface,
            // .schip1_1 => self._real_interpreter.schip1_1.base.draw_surface,
            // .schip_modern => self._real_interpreter.schip_modern.base.draw_surface,
            .chip_64 => self._real_interpreter.chip_64.draw_surface,
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }

    pub fn getWidth(self: *@This()) i32 {
        return switch (self._tag) {
            .chip_8 => @intCast(self._real_interpreter.chip8.base.draw_w),
            // .schip1_0 => @intCast(self._real_interpreter.schip1_0.base.draw_w),
            // .schip1_1 => @intCast(self._real_interpreter.schip1_1.base.draw_w),
            // .schip_modern => @intCast(self._real_interpreter.schip_modern.base.draw_w),
            .chip_64 => self._real_interpreter.chip_64.draw_surface.w,
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }

    pub fn getHeight(self: *@This()) i32 {
        return switch (self._tag) {
            .chip_8 => @intCast(self._real_interpreter.chip8.base.draw_h),
            // .schip1_0 => @intCast(self._real_interpreter.schip1_0.base.draw_h),
            // .schip1_1 => @intCast(self._real_interpreter.schip1_1.base.draw_h),
            // .schip_modern => @intCast(self._real_interpreter.schip_modern.base.draw_h),
            .chip_64 => self._real_interpreter.chip_64.draw_surface.h,
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }

    pub fn getInputsPointer(self: *@This()) *Inputs {
        return switch (self._tag) {
            .chip_8 => &self._real_interpreter.chip8.base.user_inputs,
            // .schip1_0 => &self._real_interpreter.schip1_0.base.user_inputs,
            // .schip1_1 => &self._real_interpreter.schip1_1.base.user_inputs,
            // .schip_modern => &self._real_interpreter.schip_modern.base.user_inputs,
            .chip_64 => &self._real_interpreter.chip_64.user_inputs,
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }

    pub fn getSoundTimer(self: *@This()) u8 {
        return switch (self._tag) {
            .chip_8 => self._real_interpreter.chip8.base.sound_timer,
            // .schip1_0 => self._real_interpreter.schip1_0.base.sound_timer,
            // .schip1_1 => self._real_interpreter.schip1_1.base.sound_timer,
            // .schip_modern => self._real_interpreter.schip_modern.base.sound_timer,
            .chip_64 => self._real_interpreter.chip_64.sound_timer,
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }

    pub fn getHertzCounter(self: *@This()) u64 {
        return switch (self._tag) {
            .chip_8 => self._real_interpreter.chip8.base.hertz_counter,
            // .schip1_0 => self._real_interpreter.schip1_0.base.hertz_counter,
            // .schip1_1 => self._real_interpreter.schip1_1.base.hertz_counter,
            // .schip_modern => self._real_interpreter.schip_modern.base.hertz_counter,
            .chip_64 => self._real_interpreter.chip_64.hertz_counter,
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }

    pub fn execNextIntstruction(self: *@This(), allocator: std.mem.Allocator) !?ExtraWork {
        return switch (self._tag) {
            .chip_8 => self._real_interpreter.chip8.execNextInstruction(allocator),
            // .schip1_0 => self._real_interpreter.schip1_0.execNextInstruction(allocator),
            // .schip1_1 => self._real_interpreter.schip1_1.execNextInstruction(allocator),
            // .schip_modern => self._real_interpreter.schip_modern.execNextInstruction(allocator),
            .chip_64 => self._real_interpreter.chip_64.execNextInstruction(allocator),
            // temp code until I get back the other interpreter implementations
            else => unreachable,
        };
    }
};
