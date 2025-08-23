const std = @import("std");
const Args = @import("args.zig");
// const Chip8 = @import("actual_assemblers/chip_8.zig");
// const Schip10 = @import("actual_assemblers/schip1_0.zig");
// const Schip11 = @import("actual_assemblers/schip1_1.zig");
// const SchipModern = @import("actual_assemblers/schip_modern.zig");
const Chip64 = @import("actual_assemblers/chip_64.zig");

/// Returns assembled code
pub fn assemble(build_target: Args.Build, allocator: std.mem.Allocator, binary_start_index: ?u64, code: []u8) ![]u8 {
    switch (build_target) {
        // .chip_8 => return try Chip8.assemble(allocator, binary_start_index, code),
        // .schip_1_0 => return try Schip10.assemble(allocator, binary_start_index, code),
        // .schip_1_1 => return try Schip11.assemble(allocator, binary_start_index, code),
        // .schip_modern => return try SchipModern.assemble(allocator, binary_start_index, code),
        .chip_64 => return try Chip64.assemble(allocator, binary_start_index, code),
        else => return error.@"NotImplemented Deal with it, yes that's spaces in an error message",
    }
}
