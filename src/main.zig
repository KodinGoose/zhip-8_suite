const std = @import("std");
const builtin = @import("builtin");
var debug_allocator = if (builtin.mode == .Debug) std.heap.DebugAllocator(.{}).init else null;
const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;

const assembler = @import("assembler.zig");
const de_assembler = @import("de_assembler.zig");
const arg_handler = @import("args.zig");

pub fn main() !void {
    defer if (builtin.mode == .Debug) {
        _ = debug_allocator.deinit();
    };

    var args = arg_handler.handleArgs(allocator) catch |err| {
        if (err != error.HelpAsked) return err else {
            try std.io.getStdOut().writer().writeAll(
                \\Usage: chip_assembler [args]
                \\Example: chip_assembler -s "main.chs" -b "pong.ch8" -dBn chip-8 decimal
                \\
                \\Args:
                \\    i: Specify the index where the code starts (relevant for labels)
                \\    A: Use assembly like equivalents of the commands (Only has an effect in de_assembler mode)
                \\    a: Assemble source code
                \\    d: De-assemble binary
                \\    s [source_file_name]: Specify the source file's name
                \\    b [binary_file_name]: Specify the binary file's name
                \\    B [build_target]: Specify a build target
                \\    n [number_base]: Specify the base to use for numbers, only has an effect while disassembling
                \\    h: Print this help text and exit
                \\
                \\Supported build targets:
                \\    chip-8
                \\    schip1.0
                \\    schip1.1
                \\
                \\Supported number bases (N is a digit):
                \\    binary: 0bNNNNNNNN
                \\    octal: 0oNNN
                \\    decimal: NNN
                \\    hexadecimal (default): 0xNN
                \\
            );
            return;
        }
    };
    defer args.deinit();

    const wd = std.fs.cwd();

    if (args.job == .assemble) {
        const file = try wd.openFile(args.source_file_name._name, .{});
        defer file.close();
        const file_contents = try file.readToEndAlloc(allocator, try file.getEndPos());
        defer allocator.free(file_contents);
        const lines = try assembler.translate(allocator, args.binary_start_index, file_contents);
        defer allocator.free(lines);
        const file2 = try wd.createFile(args.binary_file_name._name, .{});
        defer file2.close();
        const byte_lines: []u8 = @ptrCast(lines);
        try file2.writeAll(byte_lines);
    } else if (args.job == .de_assemble) {
        const file = try wd.openFile(args.binary_file_name._name, .{});
        defer file.close();
        const file_contents = try file.readToEndAlloc(allocator, try file.getEndPos());
        defer allocator.free(file_contents);
        const lines = try de_assembler.translate(allocator, args, file_contents);
        defer allocator.free(lines);
        const file2 = try wd.createFile(args.source_file_name._name, .{});
        defer file2.close();
        try file2.writeAll(lines);
    }
}

test "assemble + de-assemble" {
    const file_contents = try std.testing.allocator.dupe(u8, @embedFile("./de_assemble_test.ch8"));
    defer std.testing.allocator.free(file_contents);
    const lines = try de_assembler.translate(
        std.testing.allocator,
        .{ .source_file_name = undefined, .binary_file_name = undefined },
        file_contents,
    );
    defer std.testing.allocator.free(lines);
    const lines2 = try assembler.translate(
        std.testing.allocator,
        (arg_handler.Args{ .source_file_name = undefined, .binary_file_name = undefined }).binary_start_index,
        @constCast(lines),
    );
    defer std.testing.allocator.free(lines2);
    const byte_lines: []u8 = @ptrCast(lines2);
    try std.testing.expect(std.mem.eql(u8, file_contents, byte_lines));
}
