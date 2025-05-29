const std = @import("std");

/// Always returns err
pub fn printReturnError(err: anyerror, message: []const u8) @TypeOf(err) {
    std.io.getStdOut().writer().print("{s}\n", .{message}) catch {};
    return err;
}

/// Always returns error.AssembleError
pub fn printAssembleError(message: []const u8, line_number: usize) error{AssembleError} {
    std.io.getStdOut().writer().print("Error at line {d}: {s}\n", .{ line_number, message }) catch {};
    return error.AssembleError;
}
