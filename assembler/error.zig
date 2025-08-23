const std = @import("std");

/// Always returns error.ErrorPrinted
pub fn printReturnError(err: anyerror, message: []const u8) error{ErrorPrinted} {
    std.io.getStdOut().writer().print("{s}\nerror: {s}\n", .{ message, @errorName(err) }) catch {};
    return error.ErrorPrinted;
}

/// Always returns error.ErrorPrinted
pub fn printAssembleError(message: []const u8, line_number: usize) error{ErrorPrinted} {
    std.io.getStdOut().writer().print("Error at line {d}: {s}\n", .{ line_number, message }) catch {};
    return error.ErrorPrinted;
}
