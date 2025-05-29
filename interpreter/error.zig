const std = @import("std");

/// Doesn't have an init function but still need to call deinit
pub const Handler = struct {
    panic_on_error: bool,
    _buf: std.ArrayListUnmanaged(u8) = .{},
    _error_count: usize = 0,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self._buf.deinit(allocator);
    }

    /// Only returns an error when self.panic_on_error == true
    pub fn handleError(self: *@This(), allocator: std.mem.Allocator, message: []const u8, err: anyerror) !void {
        self._error_count += 1;
        if (self.panic_on_error) {
            self._buf.writer(allocator).print("{s}\n", .{
                message,
            }) catch {};
            self.flush() catch {};
            return err;
        } else {
            self._buf.appendNTimes(allocator, '-', 50) catch {};
            self._buf.append(allocator, '\n') catch {};
            self._buf.writer(allocator).print("{s}\nerror: {s}\n", .{
                message,
                @errorName(err),
            }) catch {};
        }
    }

    /// Only returns an error when self.panic_on_error == true
    /// Ment to solely be used by the interpreter
    pub fn handleInterpreterError(
        self: *@This(),
        allocator: std.mem.Allocator,
        message: []const u8,
        opcode_byte: u8,
        arg_byte: u8,
        prg_ptr: usize,
        err: anyerror,
    ) !void {
        self._error_count += 1;
        if (self.panic_on_error) {
            self._buf.writer(allocator).print("{s}\nOpcode: {x:0>2}{x:0>2}\nProgram pointer: {d}\n", .{
                message,
                opcode_byte,
                arg_byte,
                prg_ptr,
            }) catch {};
            self.flush() catch {};
            return err;
        } else {
            self._buf.appendNTimes(allocator, '-', 50) catch {};
            self._buf.append(allocator, '\n') catch {};
            self._buf.writer(allocator).print("{s}\nOpcode: {x:0>2}{x:0>2}\nProgram pointer: {d}\nError: {s}\n", .{
                message,
                opcode_byte,
                arg_byte,
                prg_ptr,
                @errorName(err),
            }) catch {};
        }
    }

    /// Unneccessary to call if self.panic_on_error == true
    pub fn flush(self: *@This()) !void {
        if (self._buf.items.len == 0) return;
        if (self.panic_on_error) {
            try std.io.getStdOut().writeAll(self._buf.items);
        } else {
            try std.io.getStdOut().writer().print("{s}" ++ "-" ** 50 ++ "\nAmount of errors: {d}\n", .{ self._buf.items, self._error_count });
        }
        self._buf.clearRetainingCapacity();
    }
};
