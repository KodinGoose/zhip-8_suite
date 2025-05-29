const std = @import("std");

pub fn Stack(T: type) type {
    return struct {
        _values: []T,
        _top_index: usize = 0,

        pub fn init(allocator: std.mem.Allocator, initial_capacity: usize) !@This() {
            return .{
                ._values = try allocator.alloc(T, initial_capacity),
            };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self._values);
        }

        pub fn pop(self: *@This()) !T {
            if (self._top_index == 0) return error.OutOfBounds;
            defer self._top_index -= 1;
            return self._values[self._top_index];
        }

        pub fn push(self: *@This(), allocator: std.mem.Allocator, val: T) !void {
            self._top_index += 1;
            if (self._values.len <= self._top_index) {
                self._values = try allocator.realloc(self._values, self._values.len * 2);
            }
            self._values[self._top_index] = val;
        }
    };
}
