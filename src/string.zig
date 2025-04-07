const std = @import("std");

/// Does not support negative numbers (Cause this assembler doesn't need them)
/// TODO: Make this support hexadecimanl, octal and binary
pub fn intFromString(T: type, string: []const u8) !T {
    var int: T = 0;
    const max_int_value = std.math.maxInt(T);
    for (string) |char| {
        if (char < '0' or char > '9') return error.NotInteger;
        int = try std.math.mul(T, int, 10);
        const num = try std.math.sub(u8, char, '0');
        if (num >= max_int_value) return error.Overflow;
        int = try std.math.add(T, int, @intCast(num));
    }
    return int;
}

const NumberBase = enum(u8) {
    binary,
    octal,
    decimal,
    hexadecimal,
};

/// Doesn't support negative integers because chip-8 doesn't either
/// Returned string is allocated and is owned by the caller
/// The integer is expected to have a fixed integer size (aka it's not a comptime_int)
pub fn stringFromInt(allocator: std.mem.Allocator, base: NumberBase, int: anytype) ![]const u8 {
    // The max value we expect is 3 characters long
    var string = try std.ArrayList(u8).initCapacity(allocator, 3);
    errdefer string.deinit();
    var integer: if (@bitSizeOf(@TypeOf(int)) < 8) u8 else @TypeOf(int) = int;
    switch (base) {
        .binary => {
            try string.append(@as(u8, @intCast(integer % 2)) + '0');
            integer /= 2;
            while (integer > 0) {
                try string.append(@as(u8, @intCast(integer % 2)) + '0');
                integer /= 2;
            }
        },
        .octal => {
            try string.append(@as(u8, @intCast(integer % 8)) + '0');
            integer /= 8;
            while (integer > 0) {
                try string.append(@as(u8, @intCast(integer % 8)) + '0');
                integer /= 8;
            }
        },
        .decimal => {
            try string.append(@as(u8, @intCast(integer % 10)) + '0');
            integer /= 10;
            while (integer > 0) {
                try string.append(@as(u8, @intCast(integer % 10)) + '0');
                integer /= 10;
            }
        },
        .hexadecimal => {
            var num = @as(u8, @intCast(integer % 16));
            if (num >= 10) {
                // 10 + 55 == 65 (A)
                try string.append(num + 55);
            } else {
                try string.append(num + '0');
            }
            integer /= 16;
            while (integer > 0) {
                num = @as(u8, @intCast(integer % 16));
                if (num >= 10) {
                    // 10 + 55 == 65 (A)
                    try string.append(num + 55);
                } else {
                    try string.append(num + '0');
                }
                integer /= 16;
            }
        },
    }
    reverseString(string.items);
    // This was in a defer statement right after initialization but the zig compilers with versions
    // higher than 0.13 don't like it for some reason and causes a segfault at runtime
    string.shrinkAndFree(string.items.len);
    return string.items;
}

test "stringFromInt" {
    var debug_allocator = std.testing.allocator_instance;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    const int1: u64 = 0b10011101;
    const int2: u64 = 0o12345670;
    const int3: u64 = 1234567890;
    const int4: u64 = 0x123456789ABCDEF0;

    const string1 = try stringFromInt(allocator, .binary, int1);
    defer allocator.free(string1);
    const string2 = try stringFromInt(allocator, .octal, int2);
    defer allocator.free(string2);
    const string3 = try stringFromInt(allocator, .decimal, int3);
    defer allocator.free(string3);
    const string4 = try stringFromInt(allocator, .hexadecimal, int4);
    defer allocator.free(string4);

    try std.testing.expect(std.mem.eql(u8, string1, "10011101"));
    try std.testing.expect(std.mem.eql(u8, string2, "12345670"));
    try std.testing.expect(std.mem.eql(u8, string3, "1234567890"));
    try std.testing.expect(std.mem.eql(u8, string4, "123456789ABCDEF0"));
}

/// Reverses the string in place
pub fn reverseString(string: []u8) void {
    for (0..string.len / 2) |i| {
        const tmp = string[i];
        string[i] = string[string.len - 1 - i];
        string[string.len - 1 - i] = tmp;
    }
}

pub fn containsLettersOnly(string: []const u8) bool {
    for (string) |char| if ((char < 'a' or char > 'z') and (char < 'A' or char > 'Z')) return false;
    return true;
}

/// Converts to lower case in place
pub fn toLowerCase(string: []u8) void {
    for (string) |*char| {
        if (char.* < 'A' or char.* > 'Z') continue;
        // A (65) + 32 = a (97)
        char.* += 32;
    }
}
