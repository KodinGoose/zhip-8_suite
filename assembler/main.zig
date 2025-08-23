const std = @import("std");
const builtin = @import("builtin");
var debug_allocator = if (builtin.mode == .Debug) std.heap.DebugAllocator(.{}).init else null;
const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;

const assembler = @import("assembler.zig");
const de_assembler = @import("de_assembler.zig");
const ArgHandler = @import("args.zig");
const ErrorHandler = @import("error.zig");

pub fn main() !void {
    defer if (builtin.mode == .Debug) {
        _ = debug_allocator.deinit();
    };

    var args = ArgHandler.handleArgs(allocator) catch |err| {
        if (err == error.HelpAsked) {
            try std.io.getStdOut().writer().writeAll(
                \\Usage: chip_assembler [input_file_name] [args]
                \\Example: chip_assembler -s "main.chs" -b "pong.ch8" -dBn chip-8 decimal
                \\
                \\Args:
                \\    s: Specify the index where the code starts (relevant for labels)
                \\    A: Use assembly like equivalents of the commands (Only has an effect in de_assembler mode)
                \\    a: Assemble source code
                \\    d: De-assemble binary
                \\    o [output_file_name]: Specify the output file's name
                \\    B [build_target]: Specify a build target
                \\    n [number_base]: Specify the base to use for numbers, only has an effect while disassembling
                \\    h: Print this help text and exit
                \\    C: Client mode (Do not use this flag)
                \\
                \\Supported build targets:
                \\    chip-8
                \\    schip1.0
                \\    schip1.1
                \\    schip-modern
                \\    chip-64
                \\
                \\Supported number bases (N is a digit):
                \\    binary: 0bNNNNNNNN
                \\    octal: 0oNNN
                \\    decimal: NNN
                \\    hexadecimal (default): 0xNN
                \\
            );
            return;
        } else if (err == error.ErrorPrinted) {
            return;
        } else {
            ErrorHandler.printReturnError(err, "Unexpected error") catch {};
            return;
        }
    };
    defer args.deinit(allocator);

    const wd = std.fs.cwd();

    if (args.job == .assemble) {
        const file = wd.openFile(args.input_file_name.name.?, .{}) catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't open the input file") catch return;
        };
        defer file.close();
        const file_contents = file.readToEndAlloc(allocator, file.getEndPos() catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't read from the input file") catch return;
        }) catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't read from the input file") catch return;
        };
        defer allocator.free(file_contents);
        const binary = assembler.assemble(args.build, allocator, args.binary_start_index, file_contents) catch |err| {
            if (err == error.ErrorPrinted) return;
            ErrorHandler.printReturnError(err, "Couldn't translate code into binary") catch return;
        };
        defer allocator.free(binary);
        const file2 = wd.createFile(args.output_file_name.name.?, .{}) catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't create output file") catch return;
        };
        defer file2.close();
        file2.writeAll(binary) catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't write to output file") catch return;
        };
    } else if (args.job == .de_assemble) {
        const file = wd.openFile(args.input_file_name.name.?, .{}) catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't open the input file") catch return;
        };
        defer file.close();
        const file_contents = file.readToEndAlloc(allocator, file.getEndPos() catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't read from the input file") catch return;
        }) catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't read from the input file") catch return;
        };
        defer allocator.free(file_contents);
        const lines = de_assembler.translate(allocator, args, file_contents) catch |err| {
            // Currently the de_assembler cannot return error.ErrorPrinted
            // if (err == error.ErrorPrinted) return;
            ErrorHandler.printReturnError(err, "Couldn't translate binary into code") catch return;
        };
        defer allocator.free(lines);
        const file2 = wd.createFile(args.output_file_name.name.?, .{}) catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't create output file") catch return;
        };
        defer file2.close();
        file2.writeAll(lines) catch |err| {
            ErrorHandler.printReturnError(err, "Couldn't write to output file") catch return;
        };
    }
}

test "assemble + de-assemble" {
    const file_contents = try std.testing.allocator.dupe(u8, @embedFile("./de_assemble_test.ch8"));
    defer std.testing.allocator.free(file_contents);
    const lines = try de_assembler.translate(
        std.testing.allocator,
        .{ .input_file_name = undefined, .output_file_name = undefined },
        file_contents,
    );
    defer std.testing.allocator.free(lines);
    const lines2 = try assembler.translate(
        std.testing.allocator,
        (ArgHandler.Args{ .input_file_name = undefined, .output_file_name = undefined }).binary_start_index,
        @constCast(lines),
    );
    defer std.testing.allocator.free(lines2);
    const byte_lines: []u8 = @ptrCast(lines2);
    try std.testing.expect(std.mem.eql(u8, file_contents, byte_lines));
}
