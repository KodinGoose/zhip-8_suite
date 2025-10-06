const std = @import("std");
const Args = @import("args.zig");
const Base = @import("assembler_implementations/base.zig");
const Chip8 = @import("assembler_implementations/chip_8.zig");
// const Schip10 = @import("actual_assemblers/schip1_0.zig");
// const Schip11 = @import("actual_assemblers/schip1_1.zig");
// const SchipModern = @import("actual_assemblers/schip_modern.zig");
const Chip64 = @import("assembler_implementations/chip_64.zig");

/// Returns assembled code
pub fn assemble(build_target: Args.Build, allocator: std.mem.Allocator, error_writer: *std.Io.Writer, args: Args.Args, code: []u8) ![]u8 {
    switch (build_target) {
        .chip_8 => return try Base.assemble(allocator, error_writer, args, code, Chip8.AddressT, Chip8.assembleInstructions),
        // .schip_1_0 => return try Base.assemble(allocator, error_writer, args, code, Chip8.AddressT, Chip8.assembleInstructions),
        // .schip_1_1 => return try Base.assemble(allocator, error_writer, args, code, Chip8.AddressT, Chip8.assembleInstructions),
        // .schip_modern => return try Base.assemble(allocator, error_writer, args, code, Chip8.AddressT, Chip8.assembleInstructions),
        .chip_64 => return try Base.assemble(allocator, error_writer, args, code, Chip64.AddressT, Chip64.assembleInstructions),
        else => return error.@"Not implemented, too bad.",
    }
}
