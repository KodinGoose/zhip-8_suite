const std = @import("std");

/// Reverses the array in place
pub fn reverseArray(T: type, array: []T) void {
    for (0..array.len / 2) |i| {
        const tmp = array[i];
        array[i] = array[array.len - 1 - i];
        array[array.len - 1 - i] = tmp;
    }
}

test "reverseArray" {
    var allocator = std.testing.allocator;

    const string1 = try allocator.dupe(u8, "12345");
    defer allocator.free(string1);
    const string2 = try allocator.dupe(u8, "54321");
    defer allocator.free(string2);
    const string3 = try allocator.dupe(u8, "aHSb21t");
    defer allocator.free(string3);
    const string4 = try allocator.dupe(u8, "");
    defer allocator.free(string4);

    reverseArray(u8, string1);
    reverseArray(u8, string2);
    reverseArray(u8, string3);
    reverseArray(u8, string4);

    try std.testing.expect(std.mem.eql(u8, string1, "54321"));
    try std.testing.expect(std.mem.eql(u8, string2, "12345"));
    try std.testing.expect(std.mem.eql(u8, string3, "t12bSHa"));
    try std.testing.expect(std.mem.eql(u8, string4, ""));
}

/// Returned array is reversed
pub fn reverseArrayAlloc(allocator: std.mem.Allocator, T: type, array: []const T) ![]u8 {
    const new_array = try allocator.dupe(T, array);
    errdefer allocator.free(new_array);
    reverseArray(T, new_array);
    return new_array;
}

pub fn concat(allocator: std.mem.Allocator, T: type, a: []const T, b: []const T) ![]u8 {
    var new_array = try allocator.alloc(T, a.len + b.len);
    @memcpy(new_array[0..a.len], a);
    @memcpy(new_array[a.len..], b);
    return new_array;
}

test "concat" {
    const allocator = std.testing.allocator;
    const string1: []const u8 = "asdf";
    const string2: []const u8 = "fdsa";
    const concated = try concat(allocator, u8, string1, string2);
    defer allocator.free(concated);
    try std.testing.expect(std.mem.eql(u8, concated, "asdffdsa"));
}
