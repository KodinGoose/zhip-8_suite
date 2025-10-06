const std = @import("std");
const builtin = @import("builtin");

const Base = @import("base.zig");

const Array = @import("shared").Array;
const BigInt = @import("shared").BigInt;
const String = @import("shared").String;

const ErrorHandler = @import("../error.zig");

const cpu_endianness = builtin.cpu.arch.endian();
pub const AddressT = u64;

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

        if (Base.eql(assembly_opcode, "halt")) {
            try binary.append(allocator, 0x00);
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "exit")) {
            try binary.append(allocator, 0x01);
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "clear")) {
            try binary.append(allocator, 0x02);
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "ret")) {
            try binary.append(allocator, 0x03);
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "window")) {
            const arg = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);

            if (Base.eql(arg, "lock")) {
                try binary.append(allocator, 0x04);
            } else if (Base.eql(arg, "match")) {
                try binary.append(allocator, 0x05);
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
                continue :line_loop;
            }
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "resolution")) {
            try binary.append(allocator, 0x06);
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;
        } else if (Base.eql(assembly_opcode, "jump")) blk: {
            try binary.append(allocator, 0x10);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            const opt_num: ?u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .optional, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            };
            if (opt_num == null) break :blk;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(opt_num.?)));
            binary_index.* += 2;

            const arg = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);
            if (!Base.eql(arg, "if")) {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            const arg2 = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg2);
            if (Base.eql(arg2, "<")) {
                binary.items[instruction_index] += 1;
            } else if (Base.eql(arg2, "<=")) {
                binary.items[instruction_index] += 2;
            } else if (Base.eql(arg2, ">")) {
                binary.items[instruction_index] += 3;
            } else if (Base.eql(arg2, ">=")) {
                binary.items[instruction_index] += 4;
            } else if (Base.eql(arg2, "==")) {
                binary.items[instruction_index] += 5;
            } else if (Base.eql(arg2, "!=")) {
                binary.items[instruction_index] += 6;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (Base.eql(assembly_opcode, "call")) {
            try binary.append(allocator, 0x17);
            binary_index.* += 1;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (Base.eql(assembly_opcode, "reserve")) {
            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            const opt_amt: ?usize = Base.getInt(allocator, error_writer, usize, usize, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .optional, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            };
            if (opt_amt != null) {
                try binary.resize(allocator, binary.items.len + @as(usize, T_int) * opt_amt.?);
                binary_index.* += @as(usize, T_int) * opt_amt.?;
            } else {
                try binary.resize(allocator, binary.items.len + T_int);
                binary_index.* += T_int;
            }
        } else if (Base.eql(assembly_opcode, "create")) {
            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;

            var amt_of_values: usize = 0;
            var bigints = try std.ArrayListUnmanaged(BigInt).initCapacity(allocator, 8);
            defer bigints.deinit(allocator);
            defer for (bigints.items) |*bigint| bigint.deinit(allocator);

            while (true) {
                var opt_value: ?BigInt = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .optional, .allow_alias) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                };
                if (opt_value != null) {
                    errdefer opt_value.?.deinit(allocator);
                    try bigints.append(allocator, opt_value.?);
                    amt_of_values += 1;
                } else {
                    break;
                }
            }

            var tmp_i: usize = binary.items.len;
            try binary.resize(allocator, binary.items.len + T_int * amt_of_values);
            for (bigints.items) |bigint| {
                bigint.writeBigEndian(binary.items[tmp_i .. tmp_i + T_int]);
                tmp_i += T_int;
            }
            binary_index.* += T_int * amt_of_values;
            std.debug.assert(binary_index.* == binary.items.len);
        } else if (Base.eql(assembly_opcode, "alloc")) blk: {
            try binary.append(allocator, 0x20);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getInt(allocator, error_writer, u64, u64, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .dont_allow_alias, .big) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 8;
        } else if (Base.eql(assembly_opcode, "free")) blk: {
            try binary.append(allocator, 0x22);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getInt(allocator, error_writer, u64, u64, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .dont_allow_alias, .big) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 8;
        } else if (Base.eql(assembly_opcode, "set")) blk: {
            try binary.append(allocator, 0x30);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "add")) blk: {
            try binary.append(allocator, 0x40);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "sub")) blk: {
            try binary.append(allocator, 0x42);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "mul")) blk: {
            try binary.append(allocator, 0x44);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "div")) blk: {
            try binary.append(allocator, 0x46);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "mod")) blk: {
            try binary.append(allocator, 0x48);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "shift_left")) blk: {
            try binary.append(allocator, 0x50);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            try binary.appendSlice(allocator, &@as([3]u8, @bitCast(Base.getInt(allocator, error_writer, u24, u24, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 3;

            const arg = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse break :blk;
            defer allocator.free(arg);
            if (Base.eql(arg, "saturate")) {
                binary.items[instruction_index] += 1;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
        } else if (Base.eql(assembly_opcode, "shift_right")) blk: {
            try binary.append(allocator, 0x52);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            try binary.appendSlice(allocator, &@as([3]u8, @bitCast(Base.getInt(allocator, error_writer, u24, u24, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 3;

            const arg = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse break :blk;
            defer allocator.free(arg);
            if (Base.eql(arg, "saturate")) {
                binary.items[instruction_index] += 1;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
        } else if (Base.eql(assembly_opcode, "and")) blk: {
            try binary.append(allocator, 0x54);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "or")) blk: {
            try binary.append(allocator, 0x56);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "xor")) blk: {
            try binary.append(allocator, 0x58);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = Base.getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            defer bigint.deinit(allocator);
            try binary.resize(allocator, binary.items.len + T_int);
            bigint.writeBigEndian(binary.items[binary.items.len - T_int ..]);
            binary_index.* += T_int;
        } else if (Base.eql(assembly_opcode, "not")) {
            try binary.append(allocator, 0x5A);
            binary_index.* += 1;

            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (Base.eql(assembly_opcode, "rand")) {
            try binary.append(allocator, 0x5B);
            binary_index.* += 1;

            const T_int: u16 = Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (Base.eql(assembly_opcode, "key_pressed")) blk: {
            try binary.append(allocator, 0x60);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            const arg = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);
            if (Base.eql(arg, "jump")) {
                //
            } else if (Base.eql(arg, "call")) {
                binary.items[instruction_index] += 1;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }

            const arg2 = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse break :blk;
            defer allocator.free(arg2);
            if (Base.eql(arg2, "wait")) {
                binary.items[instruction_index] += 2;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
        } else if (Base.eql(assembly_opcode, "key_released")) blk: {
            try binary.append(allocator, 0x64);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            const arg = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);
            if (Base.eql(arg, "jump")) {
                //
            } else if (Base.eql(arg, "call")) {
                binary.items[instruction_index] += 1;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }

            const arg2 = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse break :blk;
            defer allocator.free(arg2);
            if (Base.eql(arg2, "wait")) {
                binary.items[instruction_index] += 2;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
        } else if (Base.eql(assembly_opcode, "present")) {
            try binary.append(allocator, 0x70);
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "draw")) {
            try binary.append(allocator, 0x71);
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(Base.getInt(allocator, error_writer, u16, u16, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (Base.eql(assembly_opcode, "time")) {
            try binary.append(allocator, 0x80);
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (Base.eql(assembly_opcode, "auto_sleep")) {
            try binary.append(allocator, 0x81);
            binary_index.* += 1;

            const arg = (try Base.getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);
            if (Base.eql(arg, "off")) {
                try binary.append(allocator, 0x00);
            } else if (Base.eql(arg, "on")) {
                try binary.append(allocator, 0x01);
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch {};
                continue :line_loop;
            }
            binary_index.* += 1;
        } else if (Base.eql(assembly_opcode, "sleep")) blk: {
            try binary.append(allocator, 0x82);
            const instruction_index = binary.items.len - 1;
            binary_index.* += 1;

            // Theoretically we could allow giving an address as a number but that is absolutely diabolical shit
            const int = Base.getInt(allocator, error_writer, u64, u64, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls, .incorrect, .dont_allow_alias, .big) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(Base.getAddress(allocator, error_writer, AddressT, AddressT, &splt_line, line_number.*, AddressT, binary_index.*, @truncate(binary_index.*), aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(int)));
            binary_index.* += 8;
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
