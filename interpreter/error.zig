const std = @import("std");

/// Doesn't have an init function but still need to call deinit
pub const Handler = struct {
    _writer: *std.Io.Writer,
    _panic_on_error: bool,
    _error_count: usize = 0,

    /// Only prints error count if self._error_count > 1
    pub fn writeErrorCount(self: *@This()) void {
        if (self._error_count > 1) {
            self._writer.print("-" ** 50 ++ "\nAmount of errors: {d}\n", .{self._error_count}) catch {};
        }
    }

    /// Only returns the error{ErrorPrinted} when self.panic_on_error == true
    pub fn handleError(self: *@This(), message: []const u8, err: anyerror) (std.Io.Writer.Error || error{ErrorPrinted})!void {
        self._error_count += 1;
        if (self._panic_on_error) {
            try self._writer.print("{s}\n", .{message});
            try self._writer.print("Error: {s}\n", .{@errorName(err)});
            try self._writer.flush();
            return error.ErrorPrinted;
        } else {
            try self._writer.writeAll(("-" ** 50) ++ "\n");
            try self._writer.print("{s}\nerror: {s}\n", .{
                message,
                @errorName(err),
            });
        }
    }

    /// Only returns error{ErrorPrinted} when self.panic_on_error == true
    /// Ment to be used solely by the interpreter
    pub fn handleInterpreterError(
        self: *@This(),
        message: []const u8,
        opcode_byte: u8,
        prg_ptr: usize,
        err: anyerror,
    ) (std.Io.Writer.Error || error{ErrorPrinted})!void {
        self._error_count += 1;
        if (self._panic_on_error) {
            try self._writer.print("{s}\nOpcode: {x:0>2}\nProgram pointer: {d} ({x})\nError: {s}\n", .{
                message,
                opcode_byte,
                prg_ptr,
                prg_ptr,
                @errorName(err),
            });
            try self._writer.flush();
            return error.ErrorPrinted;
        } else {
            try self._writer.writeAll(("-" ** 50) ++ "\n");
            try self._writer.print("{s}\nOpcode: {x:0>2}\nProgram pointer: {d} ({x})\nError: {s}\n", .{
                message,
                opcode_byte,
                prg_ptr,
                prg_ptr,
                @errorName(err),
            });
        }
    }
};
