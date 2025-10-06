const std = @import("std");

/// Always returns error.ErrorPrinted
pub fn printReturnError(writer: *std.Io.Writer, err: anyerror, message: []const u8) error{ErrorPrinted} {
    writer.print("{s}\nerror: {s}\n", .{ message, @errorName(err) }) catch {};
    return error.ErrorPrinted;
}

/// Always returns error.ErrorPrinted
pub fn printAssembleError(writer: *std.Io.Writer, message: []const u8, line_number: usize) error{ErrorPrinted} {
    writer.print("Error at line {d}: {s}\n", .{ line_number, message }) catch {};
    return error.ErrorPrinted;
}

pub fn printAssembleWarning(writer: *std.Io.Writer, message: []const u8) void {
    writer.print("Warning: {s}\n", .{message}) catch {};
}
