//! TODO: Change how this shit works, especially removing clien mode

const std = @import("std");

/// Doesn't have an init function but still need to call deinit
pub const Handler = struct {
    _panic_on_error: bool,
    _buf: std.ArrayListUnmanaged(u8) = .{},
    /// Max len of _buf.items: If _buf.items.len > _max_len _buf.items gets printed
    /// This doesn't mean that this len is never exceeded just that it will be the max after returning from a function
    /// If null this is ignored
    _max_len: ?usize,
    _error_count: usize = 0,
    /// If true then also prints the error message if self.panic_on_error = true
    _client_mode: bool,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        if (!self._panic_on_error and self._error_count > 1) {
            std.io.getStdOut().writer().print("-" ** 50 ++ "\nAmount of errors: {d}\n", .{self._error_count}) catch {};
        }
        self._buf.deinit(allocator);
    }

    /// Only returns an error when self.panic_on_error == true
    pub fn handleError(self: *@This(), allocator: std.mem.Allocator, message: []const u8, err: anyerror) !void {
        self._error_count += 1;
        if (self._panic_on_error) {
            self._buf.writer(allocator).print("{s}\n", .{message}) catch {};
            if (self._client_mode) self._buf.writer(allocator).print("Error: {s}\n", .{@errorName(err)}) catch {};
            self.flush() catch {};
            return err;
        } else {
            self._buf.appendNTimes(allocator, '-', 50) catch {};
            self._buf.append(allocator, '\n') catch {};
            self._buf.writer(allocator).print("{s}\nerror: {s}\n", .{
                message,
                @errorName(err),
            }) catch {};
            if (self._max_len != null) if (self._buf.items.len > self._max_len.?) self.flush() catch {};
        }
    }

    /// Only returns an error when self.panic_on_error == true
    /// Ment to solely be used by the interpreter
    pub fn handleInterpreterError(
        self: *@This(),
        allocator: std.mem.Allocator,
        message: []const u8,
        opcode_byte: u8,
        prg_ptr: usize,
        err: anyerror,
    ) !void {
        self._error_count += 1;
        if (self._panic_on_error) {
            self._buf.writer(allocator).print("{s}\nOpcode: {x:0>2}\nProgram pointer: {d}\n", .{
                message,
                opcode_byte,
                prg_ptr,
            }) catch {};
            if (self._client_mode) self._buf.writer(allocator).print("Error: {s}\n", .{@errorName(err)}) catch {};
            self.flush() catch {};
            return err;
        } else {
            self._buf.appendNTimes(allocator, '-', 50) catch {};
            self._buf.append(allocator, '\n') catch {};
            self._buf.writer(allocator).print("{s}\nOpcode: {x:0>2}\nProgram pointer: {d}\nError: {s}\n", .{
                message,
                opcode_byte,
                prg_ptr,
                @errorName(err),
            }) catch {};
            if (self._max_len != null) if (self._buf.items.len > self._max_len.?) self.flush() catch {};
        }
    }

    /// Unneccessary to call if self.panic_on_error == true
    pub fn flush(self: *@This()) !void {
        if (self._buf.items.len == 0) return;
        try std.io.getStdOut().writeAll(self._buf.items);
        self._buf.clearRetainingCapacity();
    }
};
