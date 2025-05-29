const std = @import("std");

pub const NumberBase = enum(u8) {
    binary,
    octal,
    decimal,
    hexadecimal,
};

/// Does not support negative numbers (Cause this assembler doesn't need them)
pub fn intFromString(T: type, string: []const u8) !T {
    var int: if (@bitSizeOf(T) < 8) u8 else T = 0;
    const int_max_value: T = std.math.maxInt(T);
    if (string.len < 2) {
        for (string) |char| {
            if (char < '0' or char > '9') return error.NotInteger;
            int = try std.math.mul(@TypeOf(int), int, 10);
            const num = try std.math.sub(u8, char, '0');
            int = try std.math.add(@TypeOf(int), int, @intCast(num));
        }
    } else if (std.mem.eql(u8, string[0..2], "0b")) {
        for (string[2..]) |char| {
            if (char < '0' or char > '1') return error.NotInteger;
            int = try std.math.mul(@TypeOf(int), int, 2);
            const num = try std.math.sub(u8, char, '0');
            int = try std.math.add(@TypeOf(int), int, @intCast(num));
        }
    } else if (std.mem.eql(u8, string[0..2], "0o")) {
        for (string[2..]) |char| {
            if (char < '0' or char > '7') return error.NotInteger;
            int = try std.math.mul(@TypeOf(int), int, 8);
            const num = try std.math.sub(u8, char, '0');
            int = try std.math.add(@TypeOf(int), int, @intCast(num));
        }
    } else if (std.mem.eql(u8, string[0..2], "0x")) {
        for (string[2..]) |char| {
            if ((char < '0' or char > '9') and !includesChar("ABCDEFabcdef", char)) return error.NotInteger;
            int = try std.math.mul(@TypeOf(int), int, 16);
            const num = try std.math.sub(u8, char, if (char <= '9') '0' else if (char <= 'F') 'A' - 10 else 'a' - 10);
            int = try std.math.add(@TypeOf(int), int, @intCast(num));
        }
    } else {
        for (string) |char| {
            if (char < '0' or char > '9') return error.NotInteger;
            int = try std.math.mul(@TypeOf(int), int, 10);
            const num = try std.math.sub(u8, char, '0');
            int = try std.math.add(@TypeOf(int), int, @intCast(num));
        }
    }
    if (int > int_max_value) return error.overflow;
    return @intCast(int);
}

test "intFromString" {
    const src1: []const u8 = "0b10011101";
    const src2: []const u8 = "0o12345670";
    const src3: []const u8 = "1234567890";
    const src4: []const u8 = "0x123456789ABCDEF0";
    const src5: []const u8 = "7";

    try std.testing.expect(0b10011101 == try intFromString(u64, src1));
    try std.testing.expect(0o12345670 == try intFromString(u64, src2));
    try std.testing.expect(1234567890 == try intFromString(u64, src3));
    try std.testing.expect(0x123456789ABCDEF0 == try intFromString(u64, src4));
    try std.testing.expect(7 == try intFromString(u64, src5));
}

/// Doesn't support negative integers because chip-8 doesn't either
/// Returned string is allocated and is owned by the caller
/// The integer is expected to have a fixed integer size (aka it's not a comptime_int)
pub fn stringFromInt(allocator: std.mem.Allocator, base: NumberBase, int: anytype) ![]const u8 {
    // The max value we expect is 4 characters long
    var string = try std.ArrayList(u8).initCapacity(allocator, 4);
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
            try string.appendSlice("b0");
        },
        .octal => {
            try string.append(@as(u8, @intCast(integer % 8)) + '0');
            integer /= 8;
            while (integer > 0) {
                try string.append(@as(u8, @intCast(integer % 8)) + '0');
                integer /= 8;
            }
            try string.appendSlice("o0");
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
            try string.appendSlice("x0");
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
    var arena = std.heap.ArenaAllocator.init(debug_allocator.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const int1: u64 = 0b10011101;
    const int2: u64 = 0o12345670;
    const int3: u64 = 1234567890;
    const int4: u64 = 0x123456789ABCDEF0;
    const string1 = try stringFromInt(allocator, .binary, int1);
    const string2 = try stringFromInt(allocator, .octal, int2);
    const string3 = try stringFromInt(allocator, .decimal, int3);
    const string4 = try stringFromInt(allocator, .hexadecimal, int4);

    try std.testing.expect(std.mem.eql(u8, string1, "0b10011101"));
    try std.testing.expect(std.mem.eql(u8, string2, "0o12345670"));
    try std.testing.expect(std.mem.eql(u8, string3, "1234567890"));
    try std.testing.expect(std.mem.eql(u8, string4, "0x123456789ABCDEF0"));
}

/// Doesn't support negative integers because chip-8 doesn't either
/// Returned string is allocated and is owned by the caller
/// The integer is expected to have a fixed integer size (aka it's not a comptime_int)
/// Buffer is modified by this function
/// If base == .decimal buffer must be able to store the maximum value of int
/// If base != .decimal buffer must be able to store the maximum value of int + 2 characters
/// Returned slice is a part of buffer
pub fn stringFromIntNoAlloc(buffer: []u8, base: NumberBase, int: anytype) []const u8 {
    var buffer_index: usize = 0;
    var integer: if (@bitSizeOf(@TypeOf(int)) < 8) u8 else @TypeOf(int) = int;
    switch (base) {
        .binary => {
            buffer[buffer_index] = @as(u8, @intCast(integer % 2)) + '0';
            integer /= 2;
            buffer_index += 1;
            while (integer > 0) {
                buffer[buffer_index] = @as(u8, @intCast(integer % 2)) + '0';
                integer /= 2;
                buffer_index += 1;
            }
            buffer[buffer_index] = 'b';
            buffer_index += 1;
            buffer[buffer_index] = '0';
            buffer_index += 1;
        },
        .octal => {
            buffer[buffer_index] = @as(u8, @intCast(integer % 8)) + '0';
            integer /= 8;
            buffer_index += 1;
            while (integer > 0) {
                buffer[buffer_index] = @as(u8, @intCast(integer % 8)) + '0';
                integer /= 8;
                buffer_index += 1;
            }
            buffer[buffer_index] = 'o';
            buffer_index += 1;
            buffer[buffer_index] = '0';
            buffer_index += 1;
        },
        .decimal => {
            buffer[buffer_index] = @as(u8, @intCast(integer % 10)) + '0';
            integer /= 10;
            buffer_index += 1;
            while (integer > 0) {
                buffer[buffer_index] = @as(u8, @intCast(integer % 10)) + '0';
                integer /= 10;
                buffer_index += 1;
            }
        },
        .hexadecimal => {
            var num = @as(u8, @intCast(integer % 16));
            if (num >= 10) {
                // 10 + 55 == 65 (A)
                buffer[buffer_index] = num + 55;
            } else {
                buffer[buffer_index] = num + '0';
            }
            integer /= 16;
            buffer_index += 1;
            while (integer > 0) {
                num = @as(u8, @intCast(integer % 16));
                if (num >= 10) {
                    // 10 + 55 == 65 (A)
                    buffer[buffer_index] = num + 55;
                } else {
                    buffer[buffer_index] = num + '0';
                }
                integer /= 16;
                buffer_index += 1;
            }
            buffer[buffer_index] = 'x';
            buffer_index += 1;
            buffer[buffer_index] = '0';
            buffer_index += 1;
        },
    }
    reverseString(buffer[0..buffer_index]);
    // This was in a defer statement right after initialization but the zig compilers with versions
    // higher than 0.13 don't like it for some reason and causes a segfault at runtime
    return buffer[0..buffer_index];
}

test "stringFromIntNoAlloc" {
    const int1: u64 = 0b10011101;
    const int2: u64 = 0o12345670;
    const int3: u64 = 1234567890;
    const int4: u64 = 0x123456789ABCDEF0;
    var buffer1: [8 + 2]u8 = [1]u8{undefined} ** 10;
    var buffer2: [8 + 2]u8 = [1]u8{undefined} ** 10;
    var buffer3: [8 + 2]u8 = [1]u8{undefined} ** 10;
    var buffer4: [16 + 2]u8 = [1]u8{undefined} ** 18;
    const string1 = stringFromIntNoAlloc(&buffer1, .binary, int1);
    const string2 = stringFromIntNoAlloc(&buffer2, .octal, int2);
    const string3 = stringFromIntNoAlloc(&buffer3, .decimal, int3);
    const string4 = stringFromIntNoAlloc(&buffer4, .hexadecimal, int4);

    try std.testing.expect(std.mem.eql(u8, string1, "0b10011101"));
    try std.testing.expect(std.mem.eql(u8, string2, "0o12345670"));
    try std.testing.expect(std.mem.eql(u8, string3, "1234567890"));
    try std.testing.expect(std.mem.eql(u8, string4, "0x123456789ABCDEF0"));
}

/// Reverses the string in place
pub fn reverseString(string: []u8) void {
    for (0..string.len / 2) |i| {
        const tmp = string[i];
        string[i] = string[string.len - 1 - i];
        string[string.len - 1 - i] = tmp;
    }
}

test "reverseString" {
    var debug_allocator = std.testing.allocator_instance;
    defer _ = debug_allocator.deinit();
    var arena = std.heap.ArenaAllocator.init(debug_allocator.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const string1 = try allocator.dupe(u8, "12345");
    const string2 = try allocator.dupe(u8, "54321");
    const string3 = try allocator.dupe(u8, "aHSb21t");
    const string4 = try allocator.dupe(u8, "");

    reverseString(string1);
    reverseString(string2);
    reverseString(string3);
    reverseString(string4);

    try std.testing.expect(std.mem.eql(u8, string1, "54321"));
    try std.testing.expect(std.mem.eql(u8, string2, "12345"));
    try std.testing.expect(std.mem.eql(u8, string3, "t12bSHa"));
    try std.testing.expect(std.mem.eql(u8, string4, ""));
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

/// Converts to upper case in place
pub fn toUpperCase(string: []u8) void {
    for (string) |*char| {
        if (char.* < 'a' or char.* > 'z') continue;
        // a (97) - 32 = A (65)
        char.* -= 32;
    }
}

pub fn includesChar(string: []const u8, char: u8) bool {
    for (string) |str_char| {
        if (str_char == char) return true;
    }
    return false;
}
