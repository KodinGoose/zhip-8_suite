const std = @import("std");
const builtin = @import("builtin");

const Base = @import("base.zig");

const Array = @import("shared").Array;
const BigInt = @import("shared").BigInt;
const String = @import("shared").String;

const ErrorHandler = @import("../error.zig");

const cpu_endianness = builtin.cpu.arch.endian();
pub const AddressT = u12;

pub fn assembleInstructions(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    splt_code: *std.mem.SplitIterator(u8, .scalar),
    line_number: *usize,
    binary_index: *usize,
    aliases: *std.StringHashMapUnmanaged(AddressT),
    alias_calls: *std.ArrayListUnmanaged(Base.AliasCall),
    binary: *std.ArrayListUnmanaged(u8),
) !void {
    splt_code.reset();
    line_loop: while (splt_code.next()) |line| {
        line_number.* += 1;
        var splt_line = std.mem.splitScalar(u8, line, ' ');

        if (Base.checkForComments(&splt_line) == .skip) continue :line_loop;

        try Base.checkForAliases(allocator, error_writer, &splt_line, line_number.*, AddressT, aliases, @truncate(binary_index.*));

        const assembly_opcode = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse continue :line_loop;
        defer allocator.free(assembly_opcode);

        if (Base.eql(assembly_opcode, "execute")) {
            var int = Base.getInt(allocator, error_writer, u12, u16, &splt_line, line_number.*, AddressT, binary_index.*, aliases, alias_calls, .strict, .dont_allow, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            int &= std.mem.nativeToBig(u16, 0x0FFF);
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(int)));
            binary_index.* += 2;
        } else if (Base.eql(assembly_opcode, "clear")) {
            try binary.append(allocator, 0x00);
            binary_index.* += 1;
            try binary.append(allocator, 0xE0);
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "ret")) {
            try binary.append(allocator, 0x00);
            binary_index.* += 1;
            try binary.append(allocator, 0xEE);
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "exit")) {
            try binary.append(allocator, 0x00);
            binary_index.* += 1;
            try binary.append(allocator, 0xFD);
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "jump")) {
            var address = Base.getAddress(allocator, error_writer, u16, &splt_line, line_number.*, AddressT, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            };
            address &= std.mem.nativeToBig(u16, 0x0FFF);
            address |= std.mem.nativeToBig(u16, 0x1000);
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(address)));
            binary_index.* += 2;
        } else if (Base.eql(assembly_opcode, "call")) {
            var address = Base.getAddress(allocator, error_writer, u16, &splt_line, line_number.*, AddressT, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            };
            address &= std.mem.nativeToBig(u16, 0x0FFF);
            address |= std.mem.nativeToBig(u16, 0x2000);
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(address)));
            binary_index.* += 2;
        } else {
            ErrorHandler.printAssembleError(error_writer, "Invalid opcode", line_number.*) catch {};
            continue :line_loop;
        }

        if (Base.checkForComments(&splt_line) == .skip) continue :line_loop;

        while (splt_line.next()) |nono| {
            if (nono.len == 0) {
                continue;
            }
            ErrorHandler.printAssembleError(error_writer, "Too many arguments", line_number.*) catch {};
            continue :line_loop;
        }
    }
}
