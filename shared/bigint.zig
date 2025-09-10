//! TODO: Do some fuzzy testing on this, especially division and modulo

const std = @import("std");
const Array = @import("array.zig");

pub const BigInt = struct {
    /// Least significant byte is the first element (little endian)
    array: []u8,

    pub fn init(allocator: std.mem.Allocator, byte_length: usize) !@This() {
        const array = try allocator.alloc(u8, byte_length);
        for (array) |*e| e.* = 0;
        return .{ .array = array };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.array);
    }

    pub fn expand(self: *@This(), expand_by: usize, allocator: std.mem.Allocator) !void {
        try self.setByteLength(self.array.len + expand_by, allocator);
    }

    pub fn setByteLength(self: *@This(), to: usize, allocator: std.mem.Allocator) !void {
        if (to > self.array.len) {
            const original_len = self.array.len;
            self.array = try allocator.realloc(self.array, to);
            for (self.array[original_len..]) |*char| char.* = 0;
        } else {
            self.array = try allocator.realloc(self.array, to);
        }
    }

    /// Bytes are still interpreted as little endian
    pub fn reverseByteOrder(self: *@This()) void {
        Array.reverseArray(u8, self.array);
    }

    /// Buffer must be the same length as self.array
    pub fn writeBigEndian(self: @This(), buffer: []u8) void {
        std.debug.assert(self.array.len == buffer.len);
        var self_index = self.array.len;
        var buffer_index: usize = 0;
        while (self_index > 0) {
            self_index -= 1;
            buffer[buffer_index] = self.array[self_index];
            buffer_index += 1;
        }
    }

    /// Buffer must be the same length as self.array
    /// So obviously copy pasted from write variant
    pub fn readBigEndian(self: @This(), buffer: []u8) void {
        std.debug.assert(self.array.len == buffer.len);
        var self_index = self.array.len;
        var buffer_index: usize = 0;
        while (self_index > 0) {
            self_index -= 1;
            self.array[self_index] = buffer[buffer_index];
            buffer_index += 1;
        }
    }

    /// Other must be the same byte length as self.array
    pub fn isLessThan(self: @This(), other: @This()) bool {
        std.debug.assert(self.array.len == other.array.len);
        var i = self.array.len -% 1;

        while (i != std.math.maxInt(usize)) : (i -%= 1) {
            if (self.array[i] < other.array[i])
                return true
            else if (self.array[i] > other.array[i])
                return false
            else
                continue;
        }

        return false;
    }

    /// Other must be the same byte length as self.array
    pub fn isLessThanEqual(self: @This(), other: @This()) bool {
        std.debug.assert(self.array.len == other.array.len);
        var i = self.array.len -% 1;

        while (i != std.math.maxInt(usize)) : (i -%= 1) {
            if (self.array[i] < other.array[i])
                return true
            else if (self.array[i] > other.array[i])
                return false
            else
                continue;
        }

        return true;
    }

    /// Self.array.len and other.array.len must be the same
    /// Result.array.len equals self.array.len
    pub fn add(self: @This(), other: @This(), allocator: std.mem.Allocator) !@This() {
        std.debug.assert(self.array.len == other.array.len);
        var result = try BigInt.init(allocator, self.array.len);
        // Technically there is no point to this
        errdefer result.deinit(allocator);
        var carry: bool = false;
        var tuple: struct { u8, u1 } = .{ 0, 0 };
        for (self.array, other.array, result.array) |self_e, other_e, *result_e| {
            tuple = @addWithOverflow(self_e, other_e);
            if (carry) {
                const tuple2 = @addWithOverflow(tuple[0], 1);
                std.debug.assert(!(tuple[1] == 1 and tuple2[1] == 1));
                if (tuple2[1] == 1) tuple[1] = 1;
                tuple[0] = tuple2[0];
            }
            carry = if (tuple[1] == 1) true else false;
            result_e.* = tuple[0];
        }
        return result;
    }

    /// Self.array.len and other.array.len must be the same
    /// Returns true on overflow and false otherwise
    pub fn addInPlace(self: *@This(), other: @This()) bool {
        std.debug.assert(self.array.len == other.array.len);
        var carry: bool = false;
        var tuple: struct { u8, u1 } = .{ 0, 0 };
        for (self.array, other.array) |*self_e, other_e| {
            tuple = @addWithOverflow(self_e.*, other_e);
            if (carry) {
                const tuple2 = @addWithOverflow(tuple[0], 1);
                std.debug.assert(!(tuple[1] == 1 and tuple2[1] == 1));
                if (tuple2[1] == 1) tuple[1] = 1;
                tuple[0] = tuple2[0];
            }
            carry = if (tuple[1] == 1) true else false;
            self_e.* = tuple[0];
        }
        return carry;
    }

    /// Self.array.len and other.array.len must be the same
    /// Result.array.len equals self.array.len
    pub fn sub(self: @This(), other: @This(), allocator: std.mem.Allocator) !@This() {
        std.debug.assert(self.array.len == other.array.len);
        var result = try BigInt.init(allocator, self.array.len);
        // Technically there is no point to this
        errdefer result.deinit(allocator);
        var carry: bool = false;
        var tuple: struct { u8, u1 } = .{ 0, 0 };
        for (self.array, other.array, result.array) |self_e, other_e, *result_e| {
            tuple = @subWithOverflow(self_e, other_e);
            if (carry) {
                const tuple2 = @subWithOverflow(tuple[0], 1);
                std.debug.assert(!(tuple[1] == 1 and tuple2[1] == 1));
                if (tuple2[1] == 1) tuple[1] = 1;
                tuple[0] = tuple2[0];
            }
            carry = if (tuple[1] == 1) true else false;
            result_e.* = tuple[0];
        }
        return result;
    }

    /// Self.array.len and other.array.len must be the same
    /// Returns true on underflow and false otherwise
    pub fn subInPlace(self: *@This(), other: @This()) bool {
        std.debug.assert(self.array.len == other.array.len);
        var carry: bool = false;
        var tuple: struct { u8, u1 } = .{ 0, 0 };
        for (self.array, other.array) |*self_e, other_e| {
            tuple = @subWithOverflow(self_e.*, other_e);
            if (carry) {
                const tuple2 = @subWithOverflow(tuple[0], 1);
                std.debug.assert(!(tuple[1] == 1 and tuple2[1] == 1));
                if (tuple2[1] == 1) tuple[1] = 1;
                tuple[0] = tuple2[0];
            }
            carry = if (tuple[1] == 1) true else false;
            self_e.* = tuple[0];
        }
        return carry;
    }

    /// Self.array.len and other.array.len must be the same
    /// Result.array.len equals self.array.len
    /// Algorithm is from: "The Art of Computer Programming volume 2" by Donald Knuth
    /// This is "algorithm M"
    pub fn mul(self: @This(), other: @This(), allocator: std.mem.Allocator) !@This() {
        std.debug.assert(self.array.len == other.array.len);

        var result = try self.mulNoCutOff(other, allocator);
        errdefer result.deinit(allocator);

        result.array = try allocator.realloc(result.array, self.array.len);
        return result;
    }

    /// Self.array.len and other.array.len must be the same
    /// Algorithm is from: "The Art of Computer Programming volume 2" by Donald Knuth
    /// This is "algorithm M"
    /// Invalidates pointers to self.array
    /// Returns true on overflow and false otherwise
    pub fn mulInPlace(self: *@This(), other: @This(), allocator: std.mem.Allocator) !bool {
        std.debug.assert(self.array.len == other.array.len);
        var overflow = false;

        var result = try self.mulNoCutOff(other, allocator);
        defer result.deinit(allocator);
        for (result.array[self.array.len..]) |byte| {
            if (byte != 0) overflow = true;
        }

        @memcpy(self.array, result.array[0..self.array.len]);
        return overflow;
    }

    /// Self.array.len and other.array.len must be the same
    /// Result.array.len equals self.array.len + other.array.len
    /// Algorithm is from: "The Art of Computer Programming volume 2" by Donald Knuth
    /// This is "algorithm M"
    /// Result.array is w, self.array is u, other.array is v, carry is k and b (base) = 256
    pub fn mulNoCutOff(self: @This(), other: @This(), allocator: std.mem.Allocator) !@This() {
        std.debug.assert(self.array.len == other.array.len);
        // M1
        var result = try BigInt.init(allocator, self.array.len + other.array.len);
        // Technically there is no point to this
        errdefer result.deinit(allocator);

        // result.array's elements are already set to zeroes
        var j: usize = 0;
        // M2
        while (true) {
            if (other.array[j] != 0) {
                // M3
                var i: usize = 0;
                var carry: u8 = 0;
                // M4
                while (true) {
                    const t: u16 = @as(u16, self.array[i]) * other.array[j] + result.array[i + j] + carry;
                    result.array[i + j] = @intCast(t % 256);
                    carry = @intCast(t / 256);

                    // M5
                    i += 1;
                    if (i >= self.array.len) {
                        result.array[j + self.array.len] = carry;
                        break;
                    }
                }
            } else {
                result.array[j + self.array.len] = 0;
            }
            // M6
            j += 1;
            if (j >= other.array.len) break;
        }

        return result;
    }

    /// Self.array.len and other.array.len must be the same
    /// Returned.array.len equals self.array.len
    pub fn div(self: @This(), other: @This(), allocator: std.mem.Allocator) !@This() {
        std.debug.assert(self.array.len == other.array.len);
        return try self.divEx(other, allocator, .quotient);
    }

    /// Self.array.len and other.array.len must be the same
    pub fn divInPlace(self: *@This(), other: @This(), allocator: std.mem.Allocator) !void {
        std.debug.assert(self.array.len == other.array.len);
        var tmp_int = try self.div(other, allocator);
        defer tmp_int.deinit(allocator);
        @memcpy(self.array, tmp_int.array);
    }

    /// Self.array.len and other.array.len must be the same
    /// Returned.array.len equals self.array.len
    pub fn mod(self: @This(), other: @This(), allocator: std.mem.Allocator) !@This() {
        std.debug.assert(self.array.len == other.array.len);
        return try self.divEx(other, allocator, .remainder);
    }

    /// Self.array.len and other.array.len must be the same
    pub fn modInPlace(self: *@This(), other: @This(), allocator: std.mem.Allocator) !void {
        std.debug.assert(self.array.len == other.array.len);
        var tmp_int = try self.mod(other, allocator);
        defer tmp_int.deinit(allocator);
        @memcpy(self.array, tmp_int.array);
    }

    const DivReturnType = enum(u8) { quotient, remainder };

    /// b (base) = 256
    /// Algorithm is from: "The Art of Computer Programming volume 2" by Donald Knuth
    /// This is "algorithm D" from 4.3.1
    fn divEx(
        self: @This(),
        other: @This(),
        allocator: std.mem.Allocator,
        ret_type: DivReturnType,
    ) !@This() {
        std.debug.assert(self.array.len == other.array.len);

        // D1
        var v_len: usize = 0;
        for (other.array, 0..) |o_e, i| {
            if (o_e != 0) v_len = i + 1;
        }
        if (v_len == 0) return error.DivisionByZero;

        if (v_len == 1) {
            return try self.divByByte(other.array[0], allocator, ret_type);
        }

        const d: u8 = @divTrunc(256 - 1, other.array[v_len - 1]);

        const m = self.array.len - v_len;
        const n = v_len;

        // This probably doesn't need to be duped
        var v = BigInt{ .array = try allocator.dupe(u8, other.array[0..v_len]) };
        defer v.deinit(allocator);

        var u = BigInt{ .array = try allocator.alloc(u8, m + n + 1) };
        defer u.deinit(allocator);
        @memcpy(u.array[0..self.array.len], self.array);
        u.array[u.array.len - 1] = 0;

        if (d != 1) {
            var tmp_d = try BigInt.init(allocator, v_len);
            defer tmp_d.deinit(allocator);
            tmp_d.array[0] = d;
            std.debug.assert(!try v.mulInPlace(tmp_d, allocator));
            std.debug.assert(!try u.mulInPlace(tmp_d, allocator));
        }

        var q = try BigInt.init(allocator, m + 1);
        errdefer q.deinit(allocator);

        // D2
        var j = m;
        // D3
        while (true) {
            var q2: u16 = @divTrunc(@as(u16, u.array[j + n]) * 256 + u.array[j + n - 1], v.array[n - 1]);
            var r2: u16 = @mod(@as(u16, u.array[j + n]) * 256 + u.array[j + n - 1], v.array[n - 1]);
            while (true) {
                if (q2 == 256 or q2 * v.array[n - 2] > 256 * r2 + u.array[j + n - 2]) {
                    q2 -= 1;
                    r2 += v.array[n - 1];
                    if (r2 < 256) continue;
                }
                break;
            }

            // D4
            // Here Donald Knuth yaps about true values, complements and how a carry
            // (or as he calls it for some reason a "borrow") should be remembered.
            // In our case it just means let the underflow take place.
            var q2_big = try BigInt.init(allocator, v.array.len);
            defer q2_big.deinit(allocator);
            q2_big.array[0] = std.mem.asBytes(&q2)[0];
            q2_big.array[1] = std.mem.asBytes(&q2)[1];
            var q2xv = try v.mulNoCutOff(q2_big, allocator);
            defer q2xv.deinit(allocator);
            for (q2xv.array[n + 1 ..]) |byte| std.debug.assert(byte == 0);
            var u_part = BigInt{ .array = u.array[j .. j + n + 1] };
            std.debug.assert(u_part.array.len == n + 1);
            try q2xv.setByteLength(u_part.array.len, allocator);
            const has_underflowed = u_part.subInPlace(q2xv);

            // D5
            std.debug.assert(q2 < 256);
            q.array[j] = @intCast(q2);
            if (has_underflowed) {
                // D6
                @branchHint(.unlikely);
                q.array[j] -= 1;
                var tmp_v = BigInt{ .array = try allocator.alloc(u8, n + 1) };
                defer tmp_v.deinit(allocator);
                @memcpy(tmp_v.array[0..n], u_part.array);
                tmp_v.array[n] = 0;
                const overflow = u_part.subInPlace(tmp_v);
                // Should always overflow
                std.debug.assert(overflow);
            }

            // D7
            // We have to loop if j >= 0
            // j is an unsigned value
            // fuck my life
            if (j == 0) break;
            j -= 1;
        }

        if (ret_type == .quotient) {
            try q.setByteLength(self.array.len, allocator);
            return q;
        } else if (ret_type == .remainder) {
            q.deinit(allocator);
            // The quotient returned by this funtion is the remainder in our case
            const u_part = BigInt{ .array = u.array[0..self.array.len] };
            return try u_part.divByByte(d, allocator, .quotient);
        }
        unreachable;
    }

    fn divByByte(self: @This(), byte: u8, allocator: std.mem.Allocator, ret_type: DivReturnType) !@This() {
        // u = self.array
        // n = self.array.len
        // S1
        var r: u16 = 0;

        var j: usize = self.array.len - 1;
        var w = try BigInt.init(allocator, self.array.len);
        errdefer w.deinit(allocator);
        // S2
        while (true) {
            w.array[j] = @intCast(@divTrunc(r * 256 + self.array[j], byte));
            r = (r * 256 + self.array[j]) % byte;
            // S3
            if (j == 0) break;
            j -= 1;
        }
        if (ret_type == .quotient) {
            return w;
        } else if (ret_type == .remainder) {
            w.deinit(allocator);
            var rem = BigInt{ .array = try allocator.alloc(u8, self.array.len) };
            rem.array[0] = @intCast(r);
            for (rem.array[1..]) |*b| b.* = 0;
            return rem;
        }
        unreachable;
    }

    /// Self.array.len and other.array.len must be the same
    pub fn leftShiftInPlace(self: *@This(), other: @This()) void {
        std.debug.assert(self.array.len == other.array.len);
        std.debug.assert(self.array.len > 0);
        // This will never fail because of previous assert but whatever
        std.debug.assert(other.array.len > 0);
        for (other.array) |other_e| {
            var shift_by: u8 = other_e;
            while (shift_by > 0) {
                if (shift_by >= 8) {
                    var self_index: usize = self.array.len;
                    while (self_index > 1) : (self_index -= 1) {
                        self.array[self_index - 1] = self.array[self_index - 2];
                    }
                    self.array[0] = 0;
                    shift_by -= 8;
                } else {
                    const mask: u8 = @as(u8, 0xFF) << @as(u3, @intCast(8 - shift_by));
                    var carry: u8 = 0;
                    for (self.array) |*self_e| {
                        const tmp = (self_e.* & mask) >> @as(u3, @intCast(8 - shift_by));
                        self_e.* <<= @as(u3, @intCast(shift_by));
                        self_e.* |= carry;
                        carry = tmp;
                    }
                    shift_by = 0;
                }
            }
        }
    }

    /// Self.array.len and other.array.len must be the same
    pub fn leftShiftInPlaceSaturate(self: *@This(), other: @This()) void {
        std.debug.assert(self.array.len == other.array.len);
        std.debug.assert(self.array.len > 0);
        // This will never fail because of previous assert but whatever
        std.debug.assert(other.array.len > 0);
        for (other.array) |other_e| {
            var shift_by: u8 = other_e;
            while (shift_by > 0) {
                if (shift_by >= 8) {
                    var self_index: usize = self.array.len;
                    while (self_index > 1) : (self_index -= 1) {
                        self.array[self_index - 1] = self.array[self_index - 2];
                    }
                    self.array[0] = 255;
                    shift_by -= 8;
                } else {
                    const mask: u8 = @as(u8, 0xFF) << @as(u3, @intCast(8 - shift_by));
                    var carry: u8 = 0;
                    for (self.array) |*self_e| {
                        const tmp = (self_e.* & mask) >> @as(u3, @intCast(8 - shift_by));
                        self_e.* <<= @as(u3, @intCast(shift_by));
                        self_e.* |= carry;
                        carry = tmp;
                    }
                    self.array[0] |= @as(u8, 0xFF) >> @as(u3, @intCast(8 - shift_by));
                    shift_by = 0;
                }
            }
        }
    }

    /// Self.array.len and other.array.len must be the same
    pub fn rightShiftInPlace(self: *@This(), other: @This()) void {
        std.debug.assert(self.array.len == other.array.len);
        std.debug.assert(self.array.len > 0);
        // This will never fail because of previous assert but whatever
        std.debug.assert(other.array.len > 0);
        for (other.array) |other_e| {
            var shift_by: u8 = other_e;
            while (shift_by > 0) {
                if (shift_by >= 8) {
                    for (0..self.array.len - 1) |i| {
                        self.array[i] = self.array[i + 1];
                    }
                    self.array[self.array.len - 1] = 0;
                    shift_by -= 8;
                } else {
                    const mask: u8 = @as(u8, 0xFF) >> @as(u3, @intCast(8 - shift_by));
                    var carry: u8 = 0;
                    var self_index: usize = self.array.len;
                    while (self_index > 0) {
                        self_index -= 1;
                        const tmp = (self.array[self_index] & mask) << @as(u3, @intCast(8 - shift_by));
                        self.array[self_index] >>= @as(u3, @intCast(shift_by));
                        self.array[self_index] |= carry;
                        carry = tmp;
                    }
                    shift_by = 0;
                }
            }
        }
    }

    /// Self.array.len and other.array.len must be the same
    pub fn rightShiftInPlaceSaturate(self: *@This(), other: @This()) void {
        std.debug.assert(self.array.len == other.array.len);
        std.debug.assert(self.array.len > 0);
        // This will never fail because of previous assert but whatever
        std.debug.assert(other.array.len > 0);
        for (other.array) |other_e| {
            var shift_by: u8 = other_e;
            while (shift_by > 0) {
                if (shift_by >= 8) {
                    for (0..self.array.len - 1) |i| {
                        self.array[i] = self.array[i + 1];
                    }
                    self.array[self.array.len - 1] = 255;
                    shift_by -= 8;
                } else {
                    const mask: u8 = @as(u8, 0xFF) >> @as(u3, @intCast(8 - shift_by));
                    var carry: u8 = 0;
                    var self_index: usize = self.array.len;
                    while (self_index > 0) {
                        self_index -= 1;
                        const tmp = (self.array[self_index] & mask) << @as(u3, @intCast(8 - shift_by));
                        self.array[self_index] >>= @as(u3, @intCast(shift_by));
                        self.array[self_index] |= carry;
                        carry = tmp;
                    }
                    self.array[self.array.len - 1] |= @as(u8, 0xFF) << @as(u3, @intCast(8 - shift_by));
                    shift_by = 0;
                }
            }
        }
    }

    /// Self.array.len and other.array.len must be the same
    pub fn bitwiseAndInPlace(self: *@This(), other: @This()) void {
        std.debug.assert(self.array.len == other.array.len);
        for (self.array, other.array) |*self_e, other_e| {
            self_e.* &= other_e;
        }
    }

    /// Self.array.len and other.array.len must be the same
    pub fn bitwiseOrInPlace(self: *@This(), other: @This()) void {
        std.debug.assert(self.array.len == other.array.len);
        for (self.array, other.array) |*self_e, other_e| {
            self_e.* |= other_e;
        }
    }

    /// Self.array.len and other.array.len must be the same
    pub fn bitwiseXorInPlace(self: *@This(), other: @This()) void {
        std.debug.assert(self.array.len == other.array.len);
        for (self.array, other.array) |*self_e, other_e| {
            self_e.* ^= other_e;
        }
    }

    pub fn bitwiseNotInPlace(self: *@This()) void {
        for (self.array) |*self_e| self_e.* = ~self_e.*;
    }

    /// Self.array.len and other.array.len must be the same
    pub fn equals(self: @This(), other: @This()) bool {
        std.debug.assert(self.array.len == other.array.len);
        for (self.array, other.array) |s_e, o_e| if (s_e != o_e) return false;
        return true;
    }

    /// Is self > other
    /// Self.array.len and other.array.len must be the same
    pub fn greaterThan(self: @This(), other: @This()) bool {
        std.debug.assert(self.array.len == other.array.len);
        var index = self.array.len;
        while (index > 0) {
            index -= 1;
            if (self.array[index] > other.array[index]) return true;
        }
        return false;
    }
};

test "writeBigEndian" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b10101010;
    int1.array[1] = 0b01010101;
    int1.array[2] = 0b10101010;
    int1.array[3] = 0b01010101;

    const buffer = try allocator.alloc(u8, int1.array.len);
    defer allocator.free(buffer);

    int1.writeBigEndian(buffer);

    try std.testing.expect(buffer[0] == 0b01010101);
    try std.testing.expect(buffer[1] == 0b10101010);
    try std.testing.expect(buffer[2] == 0b01010101);
    try std.testing.expect(buffer[3] == 0b10101010);
}

test "readBigEndian" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);

    const buffer = try allocator.alloc(u8, int1.array.len);
    defer allocator.free(buffer);
    buffer[0] = 0b10101010;
    buffer[1] = 0b01010101;
    buffer[2] = 0b10101010;
    buffer[3] = 0b01010101;

    int1.readBigEndian(buffer);

    try std.testing.expect(int1.array[0] == 0b01010101);
    try std.testing.expect(int1.array[1] == 0b10101010);
    try std.testing.expect(int1.array[2] == 0b01010101);
    try std.testing.expect(int1.array[3] == 0b10101010);
}

test "isLessThan" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;

    var result: bool = undefined;

    result = int1.isLessThan(int2);

    try std.testing.expect(result == false);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFE;
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;

    result = int1.isLessThan(int2);

    try std.testing.expect(result == true);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFE;

    result = int1.isLessThanEqual(int2);

    try std.testing.expect(result == false);
}

test "isLessThanEqual" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;

    var result: bool = undefined;

    result = int1.isLessThanEqual(int2);

    try std.testing.expect(result == true);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFE;
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;

    result = int1.isLessThanEqual(int2);

    try std.testing.expect(result == true);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFE;

    result = int1.isLessThanEqual(int2);

    try std.testing.expect(result == false);
}

test "add" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;

    var result = try int1.add(int2, allocator);
    defer result.deinit(allocator);

    // 0000_0000 0000_0001 1111_1111 1111_1110
    try std.testing.expect(result.array[0] == 0b1111_1110);
    try std.testing.expect(result.array[1] == 0b1111_1111);
    try std.testing.expect(result.array[2] == 0b0000_0001);
    try std.testing.expect(result.array[3] == 0b0000_0000);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    int1.array[2] = 0xFF;
    int1.array[3] = 0xFF;
    int2.array[0] = 0x01;
    int2.array[1] = 0x00;
    int2.array[2] = 0x00;
    int2.array[3] = 0x00;

    var result2 = try int1.add(int2, allocator);
    defer result2.deinit(allocator);

    // 0000_0000 0000_0000 0000_0000 0000_0000
    try std.testing.expect(result2.array[0] == 0b0000_0000);
    try std.testing.expect(result2.array[1] == 0b0000_0000);
    try std.testing.expect(result2.array[2] == 0b0000_0000);
    try std.testing.expect(result2.array[3] == 0b0000_0000);
}

test "addInPlace" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;

    _ = int1.addInPlace(int2);

    // 0000_0000 0000_0001 1111_1111 1111_1110
    try std.testing.expect(int1.array[0] == 0xFE);
    try std.testing.expect(int1.array[1] == 0xFF);
    try std.testing.expect(int1.array[2] == 0x01);
    try std.testing.expect(int1.array[3] == 0x00);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    int1.array[2] = 0xFF;
    int1.array[3] = 0xFF;
    int2.array[0] = 0x01;
    int2.array[1] = 0x00;
    int2.array[2] = 0x00;
    int2.array[3] = 0x00;

    _ = int1.addInPlace(int2);

    // 0000_0000 0000_0000 0000_0000 0000_0000
    try std.testing.expect(int1.array[0] == 0x00);
    try std.testing.expect(int1.array[1] == 0x00);
    try std.testing.expect(int1.array[2] == 0x00);
    try std.testing.expect(int1.array[3] == 0x00);
}

test "sub" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0x00;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0x01;

    var result = try int1.sub(int2, allocator);
    defer result.deinit(allocator);

    // 1111_1111 1111_1111 1111_1111 1111_1111
    try std.testing.expect(result.array[0] == 0b1111_1111);
    try std.testing.expect(result.array[1] == 0b1111_1111);
    try std.testing.expect(result.array[2] == 0b1111_1111);
    try std.testing.expect(result.array[3] == 0b1111_1111);
}

test "subInPlace" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0x00;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0x01;

    _ = int1.subInPlace(int2);

    // 1111_1111 1111_1111 1111_1111 1111_1111
    try std.testing.expect(int1.array[0] == 0b1111_1111);
    try std.testing.expect(int1.array[1] == 0b1111_1111);
    try std.testing.expect(int1.array[2] == 0b1111_1111);
    try std.testing.expect(int1.array[3] == 0b1111_1111);
}

test "mul" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 64;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 4;

    var result = try int1.mul(int2, allocator);
    defer result.deinit(allocator);

    try std.testing.expect(result.array[0] == 0b0000_0000);
    try std.testing.expect(result.array[1] == 0b0000_0001);
    try std.testing.expect(result.array[2] == 0b0000_0000);
    try std.testing.expect(result.array[3] == 0b0000_0000);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;
    int2.array[2] = 0xFF;
    int2.array[3] = 0xFF;

    var result2 = try int1.mul(int2, allocator);
    defer result2.deinit(allocator);

    try std.testing.expect(result2.array[0] == 0b0000_0001);
    try std.testing.expect(result2.array[1] == 0b0000_0000);
    try std.testing.expect(result2.array[2] == 0b1111_1111);
    try std.testing.expect(result2.array[3] == 0b1111_1111);

    try int1.setByteLength(1, allocator);
    try int2.setByteLength(1, allocator);

    int1.array[0] = 0xFF;
    int2.array[0] = 0xFF;

    var result3 = try int1.mul(int2, allocator);
    defer result3.deinit(allocator);

    try std.testing.expect(result3.array[0] == 0b0000_0001);
}

test "mulNoCutOff" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;
    int2.array[2] = 0xFF;
    int2.array[3] = 0xFF;

    var result = try int1.mulNoCutOff(int2, allocator);
    defer result.deinit(allocator);

    try std.testing.expect(result.array[0] == 0b0000_0001);
    try std.testing.expect(result.array[1] == 0b0000_0000);
    try std.testing.expect(result.array[2] == 0b1111_1111);
    try std.testing.expect(result.array[3] == 0b1111_1111);
    try std.testing.expect(result.array[4] == 0b1111_1110);
    try std.testing.expect(result.array[5] == 0b1111_1111);
    try std.testing.expect(result.array[6] == 0b0000_0000);
    try std.testing.expect(result.array[7] == 0b0000_0000);
    try std.testing.expect(result.array.len == int1.array.len + int2.array.len);
}

test "div" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    int1.array[2] = 0xFF;
    int1.array[3] = 0xFF;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFF;

    var result = try int1.div(int2, allocator);
    defer result.deinit(allocator);

    try std.testing.expect(result.array[0] == 0b0000_0001);
    try std.testing.expect(result.array[1] == 0b0000_0000);
    try std.testing.expect(result.array[2] == 0b0000_0001);
    try std.testing.expect(result.array[3] == 0b0000_0000);
    try std.testing.expect(result.array.len == int1.array.len);
    try std.testing.expect(result.array.len == int2.array.len);

    int1.array[0] = 0x00;
    int1.array[1] = 0x00;
    int1.array[2] = 0x00;
    int1.array[3] = 0x00;

    var result2 = try int1.div(int2, allocator);
    defer result2.deinit(allocator);

    try std.testing.expect(result2.array[0] == 0b0000_0000);
    try std.testing.expect(result2.array[1] == 0b0000_0000);
    try std.testing.expect(result2.array[2] == 0b0000_0000);
    try std.testing.expect(result2.array[3] == 0b0000_0000);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    int1.array[2] = 0xFF;
    int1.array[3] = 0xFF;
    int2.array[0] = 0xFF;
    int2.array[1] = 0x00;
    int2.array[2] = 0x00;
    int2.array[3] = 0x00;

    var result3 = try int1.div(int2, allocator);
    defer result3.deinit(allocator);

    try std.testing.expect(result3.array[0] == 0b0000_0001);
    try std.testing.expect(result3.array[1] == 0b0000_0001);
    try std.testing.expect(result3.array[2] == 0b0000_0001);
    try std.testing.expect(result3.array[3] == 0b0000_0001);

    int1.array[0] = 0xFF;
    int1.array[1] = 0xFF;
    int1.array[2] = 0xFF;
    int1.array[3] = 0xFF;
    int2.array[0] = 0x07;
    int2.array[1] = 0x00;
    int2.array[2] = 0x00;
    int2.array[3] = 0x00;

    var result4 = try int1.div(int2, allocator);
    defer result4.deinit(allocator);

    try std.testing.expect(result4.array[0] == 0x24);
    try std.testing.expect(result4.array[1] == 0x49);
    try std.testing.expect(result4.array[2] == 0x92);
    try std.testing.expect(result4.array[3] == 0x24);
}

test "mod" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0xFF;
    int1.array[1] = 0xFE;
    int1.array[2] = 0x3F;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0xFF;
    int2.array[1] = 0xFE;

    var result = try int1.mod(int2, allocator);
    defer result.deinit(allocator);

    try std.testing.expect(result.array[0] == 0x3F);
    try std.testing.expect(result.array[1] == 0x3F);
    try std.testing.expect(result.array[2] == 0x00);
    try std.testing.expect(result.array[3] == 0x00);
}

test "leftShiftInPlace" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b1111_1111;
    int1.array[1] = 0b1111_1110;
    int1.array[2] = 0b0011_1111;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 9;

    int1.leftShiftInPlace(int2);

    try std.testing.expect(int1.array[0] == 0b0000_0000);
    try std.testing.expect(int1.array[1] == 0b1111_1110);
    try std.testing.expect(int1.array[2] == 0b1111_1101);
    try std.testing.expect(int1.array[3] == 0b0111_1111);
    try std.testing.expect(int2.array[0] == 9);
    try std.testing.expect(int2.array[1] == 0);
    try std.testing.expect(int2.array[2] == 0);
    try std.testing.expect(int2.array[3] == 0);

    int1.array[0] = 0b1111_1111;
    int1.array[1] = 0b1111_1110;
    int1.array[2] = 0b0011_1111;
    int1.array[3] = 0b0000_0000;
    int2.array[0] = 43;

    int1.leftShiftInPlace(int2);

    try std.testing.expect(int1.array[0] == 0b0000_0000);
    try std.testing.expect(int1.array[1] == 0b0000_0000);
    try std.testing.expect(int1.array[2] == 0b0000_0000);
    try std.testing.expect(int1.array[3] == 0b0000_0000);
    try std.testing.expect(int2.array[0] == 43);
    try std.testing.expect(int2.array[1] == 0);
    try std.testing.expect(int2.array[2] == 0);
    try std.testing.expect(int2.array[3] == 0);
}

test "leftShiftInPlaceSaturate" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b1111_1111;
    int1.array[1] = 0b1111_1110;
    int1.array[2] = 0b0011_1111;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 9;

    int1.leftShiftInPlaceSaturate(int2);

    try std.testing.expect(int1.array[0] == 0b1111_1111);
    try std.testing.expect(int1.array[1] == 0b1111_1111);
    try std.testing.expect(int1.array[2] == 0b1111_1101);
    try std.testing.expect(int1.array[3] == 0b0111_1111);
    try std.testing.expect(int2.array[0] == 9);
    try std.testing.expect(int2.array[1] == 0);
    try std.testing.expect(int2.array[2] == 0);
    try std.testing.expect(int2.array[3] == 0);

    int1.array[0] = 0b1111_1111;
    int1.array[1] = 0b1111_1110;
    int1.array[2] = 0b0011_1111;
    int1.array[3] = 0b0000_0000;
    int2.array[0] = 43;

    int1.leftShiftInPlaceSaturate(int2);

    try std.testing.expect(int1.array[0] == 0b1111_1111);
    try std.testing.expect(int1.array[1] == 0b1111_1111);
    try std.testing.expect(int1.array[2] == 0b1111_1111);
    try std.testing.expect(int1.array[3] == 0b1111_1111);
    try std.testing.expect(int2.array[0] == 43);
    try std.testing.expect(int2.array[1] == 0);
    try std.testing.expect(int2.array[2] == 0);
    try std.testing.expect(int2.array[3] == 0);
}

test "rightShiftInPlace" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b0000_0000;
    int1.array[1] = 0b1111_1100;
    int1.array[2] = 0b1111_1110;
    int1.array[3] = 0b1111_1111;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 9;

    int1.rightShiftInPlace(int2);

    try std.testing.expect(int1.array[0] == 0b0111_1110);
    try std.testing.expect(int1.array[1] == 0b1111_1111);
    try std.testing.expect(int1.array[2] == 0b0111_1111);
    try std.testing.expect(int1.array[3] == 0b0000_0000);
    try std.testing.expect(int2.array[0] == 9);
    try std.testing.expect(int2.array[1] == 0);
    try std.testing.expect(int2.array[2] == 0);
    try std.testing.expect(int2.array[3] == 0);

    int1.array[0] = 0b0000_0000;
    int1.array[1] = 0b1111_1100;
    int1.array[2] = 0b1111_1110;
    int1.array[3] = 0b1111_1111;
    int2.array[0] = 43;

    int1.rightShiftInPlace(int2);

    try std.testing.expect(int1.array[0] == 0b0000_0000);
    try std.testing.expect(int1.array[1] == 0b0000_0000);
    try std.testing.expect(int1.array[2] == 0b0000_0000);
    try std.testing.expect(int1.array[3] == 0b0000_0000);
    try std.testing.expect(int2.array[0] == 43);
    try std.testing.expect(int2.array[1] == 0);
    try std.testing.expect(int2.array[2] == 0);
    try std.testing.expect(int2.array[3] == 0);
}

test "rightShiftInPlaceSaturate" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b0000_0000;
    int1.array[1] = 0b1111_1100;
    int1.array[2] = 0b1111_1110;
    int1.array[3] = 0b1111_1111;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 9;

    int1.rightShiftInPlaceSaturate(int2);

    try std.testing.expect(int1.array[0] == 0b0111_1110);
    try std.testing.expect(int1.array[1] == 0b1111_1111);
    try std.testing.expect(int1.array[2] == 0b1111_1111);
    try std.testing.expect(int1.array[3] == 0b1111_1111);
    try std.testing.expect(int2.array[0] == 9);
    try std.testing.expect(int2.array[1] == 0);
    try std.testing.expect(int2.array[2] == 0);
    try std.testing.expect(int2.array[3] == 0);

    int1.array[0] = 0b0000_0000;
    int1.array[1] = 0b1111_1100;
    int1.array[2] = 0b1111_1110;
    int1.array[3] = 0b1111_1111;
    int2.array[0] = 43;

    int1.rightShiftInPlaceSaturate(int2);

    try std.testing.expect(int1.array[0] == 0b1111_1111);
    try std.testing.expect(int1.array[1] == 0b1111_1111);
    try std.testing.expect(int1.array[2] == 0b1111_1111);
    try std.testing.expect(int1.array[3] == 0b1111_1111);
    try std.testing.expect(int2.array[0] == 43);
    try std.testing.expect(int2.array[1] == 0);
    try std.testing.expect(int2.array[2] == 0);
    try std.testing.expect(int2.array[3] == 0);
}

test "bitwiseAndInPlace" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b1010_1010;
    int1.array[1] = 0b0101_0101;
    int1.array[2] = 0b1010_1010;
    int1.array[3] = 0b0101_0101;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0b1011_1010;
    int2.array[1] = 0b1101_0110;
    int2.array[2] = 0b1101_1011;
    int2.array[3] = 0b0011_0010;

    int1.bitwiseAndInPlace(int2);

    try std.testing.expect(int1.array[0] == 0b1010_1010);
    try std.testing.expect(int1.array[1] == 0b0101_0100);
    try std.testing.expect(int1.array[2] == 0b1000_1010);
    try std.testing.expect(int1.array[3] == 0b0001_0000);
}

test "bitwiseOrInPlace" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b1010_1010;
    int1.array[1] = 0b0101_0101;
    int1.array[2] = 0b1010_1010;
    int1.array[3] = 0b0101_0101;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0b1011_1010;
    int2.array[1] = 0b1101_0110;
    int2.array[2] = 0b1101_1011;
    int2.array[3] = 0b0011_0010;

    int1.bitwiseOrInPlace(int2);

    try std.testing.expect(int1.array[0] == 0b1011_1010);
    try std.testing.expect(int1.array[1] == 0b1101_0111);
    try std.testing.expect(int1.array[2] == 0b1111_1011);
    try std.testing.expect(int1.array[3] == 0b0111_0111);
}

test "bitwiseXorInPlace" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b1010_1010;
    int1.array[1] = 0b0101_0101;
    int1.array[2] = 0b1010_1010;
    int1.array[3] = 0b0101_0101;
    var int2 = try BigInt.init(allocator, 4);
    defer int2.deinit(allocator);
    int2.array[0] = 0b1011_1010;
    int2.array[1] = 0b1101_0110;
    int2.array[2] = 0b1101_1011;
    int2.array[3] = 0b0011_0010;

    int1.bitwiseXorInPlace(int2);

    try std.testing.expect(int1.array[0] == 0b0001_0000);
    try std.testing.expect(int1.array[1] == 0b1000_0011);
    try std.testing.expect(int1.array[2] == 0b0111_0001);
    try std.testing.expect(int1.array[3] == 0b0110_0111);
}

test "bitwiseNotInPlace" {
    const allocator = std.testing.allocator;
    var int1 = try BigInt.init(allocator, 4);
    defer int1.deinit(allocator);
    int1.array[0] = 0b1010_1010;
    int1.array[1] = 0b0101_0101;
    int1.array[2] = 0b1010_1010;
    int1.array[3] = 0b0101_0101;

    int1.bitwiseNotInPlace();

    try std.testing.expect(int1.array[0] == 0b0101_0101);
    try std.testing.expect(int1.array[1] == 0b1010_1010);
    try std.testing.expect(int1.array[2] == 0b0101_0101);
    try std.testing.expect(int1.array[3] == 0b1010_1010);
}
