const std = @import("std");

pub const Line = packed struct {
    /// Second byte lower bits
    number_3: u4 = 0,
    /// Second byte upper bits
    number_2: u4 = 0,
    /// first byte lower bits
    number_1: u4 = 0,
    /// first byte upper bits
    opcode: u4 = 0,

    /// Translates in place
    pub fn nativeToBigEndian(self: *Line) void {
        self.* = @bitCast(std.mem.nativeToBig(u16, @bitCast(self.*)));
    }

    /// Assumes Line is in big endian
    /// Translates in place
    pub fn BigToNative(self: *Line) void {
        self.* = @bitCast(std.mem.bigToNative(u16, @bitCast(self.*)));
    }
};
