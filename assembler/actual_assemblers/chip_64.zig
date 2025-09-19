const std = @import("std");
const builtin = @import("builtin");

const Array = @import("shared").Array;
const BigInt = @import("shared").BigInt;
const String = @import("shared").String;

const ErrorHandler = @import("../error.zig");

const cpu_endianness = builtin.cpu.arch.endian();

const AliasCall = struct {
    /// Name of the alias
    /// Assumed to be allocated
    string: []u8,
    /// The address to call
    address: u64,
    at_line: usize,
    treat_as_number: bool = false,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.string);
    }
};

/// Returns assembled code
pub fn assemble(allocator: std.mem.Allocator, error_writer: *std.Io.Writer, binary_start_index: ?u64, code: []u8) ![]u8 {
    if (binary_start_index != null) if (binary_start_index.? > std.math.maxInt(usize)) {
        return ErrorHandler.printReturnError(error_writer, error.PEBCAK, "Your architecture cannot index that big of a number");
    };
    var binary_index: usize = @intCast(if (binary_start_index == null) 0 else binary_start_index.?);

    var binary = try std.ArrayListUnmanaged(u8).initCapacity(allocator, @max(1024 * 256, binary_index));
    try binary.resize(allocator, binary_index);
    errdefer binary.deinit(allocator);
    var aliases = std.StringHashMapUnmanaged(u64){};
    defer aliases.deinit(allocator);
    defer {
        var alias_iter = aliases.keyIterator();
        while (alias_iter.next()) |key| {
            allocator.free(key.*);
        }
    }

    var alias_calls = std.ArrayListUnmanaged(AliasCall){};
    defer alias_calls.deinit(allocator);
    defer for (alias_calls.items) |*call| {
        call.deinit(allocator);
    };

    const code_copy = try allocator.dupe(u8, code);
    defer allocator.free(code_copy);
    for (code_copy) |*char| {
        if (char.* == '\r' or char.* == '\t') char.* = ' ';
    }
    var splt_code = std.mem.splitScalar(u8, code_copy, '\n');

    var line_number: usize = 0;
    try assembleInstructions(allocator, error_writer, &splt_code, &line_number, &binary_index, &aliases, &alias_calls, &binary);

    try matchAliases(error_writer, binary.items, aliases, alias_calls.items);

    binary.shrinkAndFree(allocator, binary.items.len);
    return binary.items;
}

fn assembleInstructions(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    splt_code: *std.mem.SplitIterator(u8, .scalar),
    line_number: *usize,
    binary_index: *usize,
    aliases: *std.StringHashMapUnmanaged(u64),
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
    binary: *std.ArrayListUnmanaged(u8),
) !void {
    splt_code.reset();
    line_loop: while (splt_code.next()) |line| {
        line_number.* += 1;
        var splt_line = std.mem.splitScalar(u8, line, ' ');

        if (checkForComments(&splt_line) == .skip) continue :line_loop;

        try checkForAliases(allocator, error_writer, &splt_line, line_number.*, aliases, binary_index.*);

        const assembly_opcode = (try getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse continue :line_loop;
        defer allocator.free(assembly_opcode);

        if (eql(assembly_opcode, "halt")) {
            try binary.append(allocator, 0x00);
            binary_index.* += 1;
        } else if (eql(assembly_opcode, "exit")) {
            try binary.append(allocator, 0x01);
            binary_index.* += 1;
        } else if (eql(assembly_opcode, "clear")) {
            try binary.append(allocator, 0x02);
            binary_index.* += 1;
        } else if (eql(assembly_opcode, "ret")) {
            try binary.append(allocator, 0x03);
            binary_index.* += 1;
        } else if (eql(assembly_opcode, "window")) {
            const arg = (try getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);

            if (eql(arg, "lock")) {
                try binary.append(allocator, 0x04);
            } else if (eql(arg, "match")) {
                try binary.append(allocator, 0x05);
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
                continue :line_loop;
            }
            binary_index.* += 1;
        } else if (eql(assembly_opcode, "resolution")) {
            try binary.append(allocator, 0x06);
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;
        } else if (eql(assembly_opcode, "jump")) blk: {
            try binary.append(allocator, 0x10);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            const opt_num: ?u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .optional, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            };
            if (opt_num == null) break :blk;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(opt_num.?)));
            binary_index.* += 2;

            const arg = (try getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);
            if (!eql(arg, "if")) {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            const arg2 = (try getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg2);
            if (eql(arg2, "<")) {
                binary.items[instruction_index] += 1;
            } else if (eql(arg2, "<=")) {
                binary.items[instruction_index] += 2;
            } else if (eql(arg2, ">")) {
                binary.items[instruction_index] += 3;
            } else if (eql(arg2, ">=")) {
                binary.items[instruction_index] += 4;
            } else if (eql(arg2, "==")) {
                binary.items[instruction_index] += 5;
            } else if (eql(arg2, "!=")) {
                binary.items[instruction_index] += 6;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (eql(assembly_opcode, "call")) {
            try binary.append(allocator, 0x17);
            binary_index.* += 1;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (eql(assembly_opcode, "reserve")) {
            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            const opt_amt: ?usize = getInt(allocator, error_writer, usize, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .optional, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            };
            if (opt_amt != null) {
                try binary.resize(allocator, binary.items.len + @as(usize, T_int) * opt_amt.?);
                binary_index.* += @as(usize, T_int) * opt_amt.?;
            } else {
                try binary.resize(allocator, binary.items.len + T_int);
                binary_index.* += T_int;
            }
        } else if (eql(assembly_opcode, "create")) {
            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;

            var amt_of_values: usize = 0;
            var bigints = try std.ArrayListUnmanaged(BigInt).initCapacity(allocator, 8);
            defer bigints.deinit(allocator);
            defer for (bigints.items) |*bigint| bigint.deinit(allocator);

            while (true) {
                var opt_value: ?BigInt = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .optional, .allow_alias) catch |err| {
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
        } else if (eql(assembly_opcode, "alloc")) blk: {
            try binary.append(allocator, 0x20);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getInt(allocator, error_writer, u64, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .dont_allow_alias, .big) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 8;
        } else if (eql(assembly_opcode, "free")) blk: {
            try binary.append(allocator, 0x22);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getInt(allocator, error_writer, u64, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .dont_allow_alias, .big) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
                        if (err2 == error.ErrorPrinted) continue :line_loop else return err2;
                    })));
                    binary_index.* += 8;
                    binary.items[instruction_index] += 1;
                    break :blk;
                } else if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 8;
        } else if (eql(assembly_opcode, "set")) blk: {
            try binary.append(allocator, 0x30);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "add")) blk: {
            try binary.append(allocator, 0x40);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "sub")) blk: {
            try binary.append(allocator, 0x42);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "mul")) blk: {
            try binary.append(allocator, 0x44);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "div")) blk: {
            try binary.append(allocator, 0x46);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;
            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "mod")) blk: {
            try binary.append(allocator, 0x48);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "shift_left")) blk: {
            try binary.append(allocator, 0x50);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            try binary.appendSlice(allocator, &@as([3]u8, @bitCast(getInt(allocator, error_writer, u24, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 3;

            const arg = (try getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse break :blk;
            defer allocator.free(arg);
            if (eql(arg, "saturate")) {
                binary.items[instruction_index] += 1;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
        } else if (eql(assembly_opcode, "shift_right")) blk: {
            try binary.append(allocator, 0x52);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            try binary.appendSlice(allocator, &@as([3]u8, @bitCast(getInt(allocator, error_writer, u24, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 3;

            const arg = (try getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse break :blk;
            defer allocator.free(arg);
            if (eql(arg, "saturate")) {
                binary.items[instruction_index] += 1;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
        } else if (eql(assembly_opcode, "and")) blk: {
            try binary.append(allocator, 0x54);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "or")) blk: {
            try binary.append(allocator, 0x56);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "xor")) blk: {
            try binary.append(allocator, 0x58);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
            var bigint = getBigInt(allocator, error_writer, T_int, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .allow_alias) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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
        } else if (eql(assembly_opcode, "not")) {
            try binary.append(allocator, 0x5A);
            binary_index.* += 1;

            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (eql(assembly_opcode, "rand")) {
            try binary.append(allocator, 0x5B);
            binary_index.* += 1;

            const T_int: u16 = getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, cpu_endianness) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable;
            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (eql(assembly_opcode, "key_pressed")) blk: {
            try binary.append(allocator, 0x60);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            const arg = (try getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);
            if (eql(arg, "jump")) {
                //
            } else if (eql(arg, "call")) {
                binary.items[instruction_index] += 1;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }

            const arg2 = (try getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse break :blk;
            defer allocator.free(arg2);
            if (eql(arg2, "wait")) {
                binary.items[instruction_index] += 2;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
        } else if (eql(assembly_opcode, "key_released")) blk: {
            try binary.append(allocator, 0x64);
            const instruction_index: usize = binary.items.len - 1;
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            const arg = (try getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);
            if (eql(arg, "jump")) {
                //
            } else if (eql(arg, "call")) {
                binary.items[instruction_index] += 1;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }

            const arg2 = (try getStr(allocator, error_writer, &splt_line, line_number.*, .optional)) orelse break :blk;
            defer allocator.free(arg2);
            if (eql(arg2, "wait")) {
                binary.items[instruction_index] += 2;
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch continue :line_loop;
            }
        } else if (eql(assembly_opcode, "present")) {
            try binary.append(allocator, 0x70);
            binary_index.* += 1;
        } else if (eql(assembly_opcode, "draw")) {
            try binary.append(allocator, 0x71);
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, error_writer, u16, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .strict, .dont_allow_alias, .big) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            } orelse unreachable)));
            binary_index.* += 2;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (eql(assembly_opcode, "time")) {
            try binary.append(allocator, 0x80);
            binary_index.* += 1;

            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err| {
                if (err == error.ErrorPrinted) continue :line_loop else return err;
            })));
            binary_index.* += 8;
        } else if (eql(assembly_opcode, "auto_sleep")) {
            try binary.append(allocator, 0x81);
            binary_index.* += 1;

            const arg = (try getStr(allocator, error_writer, &splt_line, line_number.*, .strict)).?;
            defer allocator.free(arg);
            if (eql(arg, "off")) {
                try binary.append(allocator, 0x00);
            } else if (eql(arg, "on")) {
                try binary.append(allocator, 0x01);
            } else {
                ErrorHandler.printAssembleError(error_writer, "Incorrect argument", line_number.*) catch {};
                continue :line_loop;
            }
            binary_index.* += 1;
        } else if (eql(assembly_opcode, "sleep")) blk: {
            try binary.append(allocator, 0x82);
            const instruction_index = binary.items.len - 1;
            binary_index.* += 1;

            // Theoretically we could allow giving an address as a number but that is absolutely diabolical shit
            const int = getInt(allocator, error_writer, u64, &splt_line, line_number.*, binary_index.*, aliases, alias_calls, .incorrect, .dont_allow_alias, .big) catch |err| {
                if (err == error.Incorrect) {
                    try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, error_writer, &splt_line, line_number.*, binary_index.*, aliases, alias_calls) catch |err2| {
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

        if (checkForComments(&splt_line) == .skip) continue :line_loop;

        while (splt_line.next()) |nono| {
            if (nono.len == 0) {
                continue;
            }
            ErrorHandler.printAssembleError(error_writer, "Too many arguments", line_number.*) catch {};
            continue :line_loop;
        }
    }
}

const Allowed = enum(u8) {
    strict,
    incorrect,
    optional,
    both,
};

/// Returns null if allowed == .optional and arg is missing
/// Allowed.incrorrect and Allowed.allow_alias has no effect and are the same as Allowed.strict
/// Prints error on other errors
fn getStr(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    allowed: Allowed,
) !?[]u8 {
    while (true) {
        const str = splt_line.peek() orelse {
            if (allowed == .optional or allowed == .both) {
                return null;
            } else {
                return ErrorHandler.printAssembleError(error_writer, "Missing argument(s)", line_number);
            }
        };

        if (str.len == 0) {
            _ = splt_line.next();
            continue;
        }
        const low_str = try String.toLowerCase(allocator, str);

        _ = splt_line.next();
        return low_str;
    }
}

/// Returns null if allowed == .optional and arg is missing
/// Allowed.incrorrect and Allowed.allow_alias has no effect and are the same as Allowed.strict
/// Prints error on other errors
/// Does not go onto the next string on success
fn getStrPeek(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    allowed: Allowed,
) !?[]u8 {
    while (true) {
        const str = splt_line.peek() orelse {
            if (allowed == .optional or allowed == .both) {
                return null;
            } else {
                return ErrorHandler.printAssembleError(error_writer, "Missing argument(s)", line_number);
            }
        };

        if (str.len == 0) {
            _ = splt_line.next();
            continue;
        }
        const low_str = try String.toLowerCase(allocator, str);

        return low_str;
    }
}

const AllowAlias = enum(u1) {
    allow_alias,
    dont_allow_alias,
};

/// Returns null if allowed == .optional and arg is missing
/// Returns error.Incorrect if allowed == .incorrect and arg is not a number
/// Prints error on other errors
fn getInt(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    T: type,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    binary_index: usize,
    aliases: *std.StringHashMapUnmanaged(u64),
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
    allowed: Allowed,
    allow_alias: AllowAlias,
    /// What endiannes the returned integer should have
    desired_endianness: std.builtin.Endian,
) !?T {
    try checkForAliases(allocator, error_writer, splt_line, line_number, aliases, binary_index);

    const str = (try getStrPeek(allocator, error_writer, splt_line, line_number, allowed)) orelse return null;
    errdefer allocator.free(str);

    if (str[0] == '*') {
        if (allow_alias == .dont_allow_alias) {
            return ErrorHandler.printAssembleError(error_writer, "Passing aliases as numbers is not allowed for this argument of this instruction", line_number);
        }

        if (@typeInfo(T).int.bits != 64) {
            return ErrorHandler.printAssembleError(error_writer, "byte length of type must be 8 bytes", line_number);
        }
        if (str.len < 2 or !String.containsLettersOnly(str[1..2]) or !String.containsPrintableAsciiOnly(str[2..])) {
            return ErrorHandler.printAssembleError(error_writer, "Invalid alias", line_number);
        }
        for (str[1..], 0..) |char, i| {
            str[i] = char;
        }
        try alias_calls.append(allocator, .{
            .string = try allocator.realloc(str, str.len - 1),
            .address = binary_index,
            .at_line = line_number,
            .treat_as_number = true,
        });

        _ = splt_line.next();
        return 0;
    }

    const int = String.intFromString(T, str) catch |err| {
        if ((allowed == .incorrect or allowed == .both) and err == error.NotInteger) {
            return error.Incorrect;
        } else {
            const concated = try Array.concat(allocator, u8, "Can't convert string to integer: ", @errorName(err));
            defer allocator.free(concated);
            return ErrorHandler.printAssembleError(error_writer, concated, line_number);
        }
    };

    _ = splt_line.next();
    allocator.free(str);
    return std.mem.nativeTo(T, int, desired_endianness);
}

/// Returns null if allowed == .optional or allowed == .both and arg is missing
/// Returns error.Incorrect if allowed == .incorrect or allowed == .both and arg is not a number
/// Prints error on other errors
fn getBigInt(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    byte_length: usize,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    binary_index: usize,
    aliases: *std.StringHashMapUnmanaged(u64),
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
    allowed: Allowed,
    allow_alias: AllowAlias,
) !?BigInt {
    try checkForAliases(allocator, error_writer, splt_line, line_number, aliases, binary_index);

    const str = (try getStrPeek(allocator, error_writer, splt_line, line_number, allowed)) orelse return null;
    errdefer allocator.free(str);

    if (str[0] == '*') {
        if (allow_alias == .dont_allow_alias) {
            return ErrorHandler.printAssembleError(error_writer, "Passing aliases as numbers is not allowed for this argument of this instruction", line_number);
        }
        if (byte_length != 8) {
            return ErrorHandler.printAssembleError(error_writer, "byte length of type must be 8 bytes", line_number);
        }
        if (str.len < 2 or !String.containsLettersOnly(str[1..2]) or !String.containsPrintableAsciiOnly(str[2..])) {
            return ErrorHandler.printAssembleError(error_writer, "Invalid alias", line_number);
        }
        for (str[1..], 0..) |char, i| {
            str[i] = char;
        }
        try alias_calls.append(allocator, .{
            .string = try allocator.realloc(str, str.len - 1),
            .address = binary_index,
            .at_line = line_number,
            .treat_as_number = true,
        });

        _ = splt_line.next();
        const bigint = try BigInt.init(allocator, byte_length);
        return bigint;
    }

    const bigint = String.bigintFromString(allocator, byte_length, str) catch |err| {
        if ((allowed == .incorrect or allowed == .both) and err == error.NotInteger) {
            return error.Incorrect;
        } else {
            const concated = try Array.concat(allocator, u8, "Can't convert string to integer: ", @errorName(err));
            defer allocator.free(concated);
            return ErrorHandler.printAssembleError(error_writer, concated, line_number);
        }
    };

    _ = splt_line.next();
    allocator.free(str);
    return bigint;
}

/// Returns zero if alias is found
/// Actual address value is filled in later
fn getAddress(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    /// Should be the address/index where the address is stored
    binary_index: usize,
    aliases: *std.StringHashMapUnmanaged(u64),
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
) !u64 {
    try checkForAliases(allocator, error_writer, splt_line, line_number, aliases, binary_index);

    const str = (try getStrPeek(allocator, error_writer, splt_line, line_number, .strict)).?;
    errdefer allocator.free(str);

    if (str[0] == ':' and str.len > 1) {
        const int = std.mem.nativeToBig(u64, String.intFromString(u64, str[1..]) catch {
            if (!String.containsLettersOnly(str[1..2]) or !String.containsPrintableAsciiOnly(str[2..])) {
                return ErrorHandler.printAssembleError(error_writer, "Invalid alias or address", line_number);
            }
            for (str[1..], 0..) |char, i| {
                str[i] = char;
            }
            try alias_calls.append(allocator, .{
                .string = try allocator.realloc(str, str.len - 1),
                .address = binary_index,
                .at_line = line_number,
            });

            _ = splt_line.next();
            return 0;
        });

        allocator.free(str);
        _ = splt_line.next();
        return int;
    }

    return ErrorHandler.printAssembleError(error_writer, "Not an address or alias", line_number);
}

const SkipLine = enum(u1) { no_skip, skip };

fn checkForComments(splt_line: *std.mem.SplitIterator(u8, .scalar)) SkipLine {
    while (splt_line.peek()) |str| {
        if (str.len == 0) {
            _ = splt_line.next();
            continue;
        }
        if (str[0] == '#') return .skip;
        break;
    }
    return .no_skip;
}

fn checkForAliases(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    aliases: *std.StringHashMapUnmanaged(u64),
    binary_index: usize,
) !void {

    // Check for alias
    while (splt_line.peek()) |str| {
        if (str.len == 0) {
            _ = splt_line.next();
            continue;
        }

        if (str[str.len - 1] == ':') {
            if (str.len < 2 or !String.containsLettersOnly(str[0..1]) or !String.containsPrintableAsciiOnly(str[1 .. str.len - 1])) {
                ErrorHandler.printAssembleError(error_writer, "Invalid alias", line_number) catch {};
                _ = splt_line.next();
                break;
            }

            const low_str = try String.toLowerCase(allocator, str);
            errdefer allocator.free(low_str);
            const ret = aliases.getEntry(low_str[0 .. low_str.len - 1]);
            if (ret) |_| {
                ErrorHandler.printAssembleError(error_writer, "Duplicate alias", line_number) catch {};
                _ = splt_line.next();
                allocator.free(low_str);
                break;
            } else {
                try aliases.put(allocator, try allocator.realloc(low_str, low_str.len - 1), binary_index);
            }
            _ = splt_line.next();
            continue;
        }
        break;
    }
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn matchAliases(error_writer: *std.Io.Writer, binary: []u8, aliases: std.StringHashMapUnmanaged(u64), alias_calls: []const AliasCall) !void {
    for (alias_calls) |*alias_call| {
        const ret = aliases.getEntry(alias_call.string);
        if (ret) |val| {
            @memcpy(
                binary[alias_call.address .. alias_call.address + 8],
                &@as([8]u8, @bitCast(std.mem.nativeToBig(@TypeOf(val.value_ptr.*), val.value_ptr.*))),
            );
        } else {
            ErrorHandler.printAssembleError(error_writer, "Non existant alias", alias_call.at_line) catch {};
        }
    }
}
