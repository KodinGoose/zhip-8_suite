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
    /// Where the address to be called is
    from: u64,
    at_line: usize,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.string);
    }
};

/// Returns assembled code
pub fn assemble(allocator: std.mem.Allocator, binary_start_index: ?u64, code: []u8) ![]u8 {
    if (binary_start_index != null) if (binary_start_index.? > std.math.maxInt(usize)) {
        return ErrorHandler.printReturnError(error.PEBCAK, "Your architecture cannot index that big of a number");
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
        if (char.* == '\r') char.* = ' ';
    }
    var splt_code = std.mem.splitScalar(u8, code_copy, '\n');

    var line_number: usize = 0;
    try assembleInstructions(allocator, &splt_code, &line_number, &binary_index, &aliases, &alias_calls, &binary);

    try matchAliases(binary.items, aliases, alias_calls.items);

    binary.shrinkAndFree(allocator, binary.items.len);
    return binary.items;
}

const Continue = enum(bool) {
    stop = false,
    keep_going = true,
};

fn assembleInstructions(
    allocator: std.mem.Allocator,
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

        // Check for alias
        while (splt_line.peek()) |str| {
            if (str.len == 0) {
                _ = splt_line.next();
                continue;
            }
            if (str[0] == '#') continue :line_loop;

            if (str[str.len - 1] == ':') {
                if (!String.containsPrintableAsciiOnly(str[0 .. str.len - 1])) {
                    ErrorHandler.printAssembleError("Aliases can only contain letters", line_number.*) catch {};
                    _ = splt_line.next();
                    break;
                }

                const low_str = try String.toLowerCase(allocator, str);
                errdefer allocator.free(low_str);
                const ret = aliases.getEntry(low_str[0 .. low_str.len - 1]);
                if (ret) |_| {
                    ErrorHandler.printAssembleError("Duplicate alias", line_number.*) catch {};
                    _ = splt_line.next();
                    break;
                } else {
                    try aliases.put(allocator, try allocator.realloc(low_str, low_str.len - 1), binary_index.*);
                }
                _ = splt_line.next();
                continue;
            }
            break;
        }

        // Actual assembling
        while (splt_line.next()) |str| {
            if (str.len == 0) {
                continue;
            }

            if (str[0] == '#') continue :line_loop;

            const assembly_opcode = try String.toLowerCase(allocator, str);
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
            } else if (eql(assembly_opcode, "return")) {
                try binary.append(allocator, 0x03);
                binary_index.* += 1;
            } else if (eql(assembly_opcode, "resolution")) {
                try binary.append(allocator, 0x04);
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, u16, &splt_line, line_number.*, .strict, .big) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable)));
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, u16, &splt_line, line_number.*, .strict, .big) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable)));
                binary_index.* += 5;
            } else if (eql(assembly_opcode, "scroll")) {
                while (true) {
                    const arg = splt_line.next() orelse {
                        ErrorHandler.printAssembleError("Missing argument(s)", line_number.*) catch continue :line_loop;
                    };
                    if (arg.len == 0) {
                        continue;
                    }

                    const low_arg = try String.toLowerCase(allocator, arg);
                    defer allocator.free(low_arg);
                    if (eql(low_arg, "up")) {
                        try binary.append(allocator, 0x05);
                    } else if (eql(low_arg, "right")) {
                        try binary.append(allocator, 0x06);
                    } else if (eql(low_arg, "down")) {
                        try binary.append(allocator, 0x07);
                    } else if (eql(low_arg, "left")) {
                        try binary.append(allocator, 0x08);
                    } else {
                        ErrorHandler.printAssembleError("Incorrect argument", line_number.*) catch continue :line_loop;
                        continue :line_loop;
                    }
                    break;
                }
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(getInt(allocator, u16, &splt_line, line_number.*, .strict, .big) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable)));
                binary_index.* += 3;
            } else if (eql(assembly_opcode, "jump")) {
                try binary.append(allocator, 0x10);
                const instruction_index: usize = binary.items.len - 1;
                binary_index.* += 1;
                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
                const opt_num: ?u16 = getInt(allocator, u16, &splt_line, line_number.*, .optional, .big) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                };
                if (opt_num != null) {
                    try binary.appendSlice(allocator, &@as([2]u8, @bitCast(opt_num.?)));
                    binary_index.* += 2;
                    while (true) {
                        const arg = splt_line.next() orelse {
                            ErrorHandler.printAssembleError("Missing argument(s)", line_number.*) catch continue :line_loop;
                        };
                        if (arg.len == 0) {
                            continue;
                        }
                        const low_arg = try String.toLowerCase(allocator, arg);
                        defer allocator.free(low_arg);
                        if (!eql(low_arg, "if")) {
                            ErrorHandler.printAssembleError("Incorrect argument", line_number.*) catch continue :line_loop;
                        }
                        try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                            if (err == error.ErrorPrinted) continue :line_loop else return err;
                        })));
                        binary_index.* += 8;

                        while (true) {
                            const arg2 = splt_line.next() orelse {
                                ErrorHandler.printAssembleError("Missing argument(s)", line_number.*) catch continue :line_loop;
                            };
                            if (arg2.len == 0) {
                                continue;
                            }
                            const low_arg2 = try String.toLowerCase(allocator, arg2);
                            defer allocator.free(low_arg2);
                            if (eql(low_arg2, "<")) {
                                binary.items[instruction_index] += 1;
                            } else if (eql(low_arg2, "<=")) {
                                binary.items[instruction_index] += 2;
                            } else if (eql(low_arg2, ">")) {
                                binary.items[instruction_index] += 3;
                            } else if (eql(low_arg2, ">=")) {
                                binary.items[instruction_index] += 4;
                            } else if (eql(low_arg2, "==")) {
                                binary.items[instruction_index] += 5;
                            } else if (eql(low_arg2, "!=")) {
                                binary.items[instruction_index] += 6;
                            } else {
                                ErrorHandler.printAssembleError("Incorrect argument", line_number.*) catch continue :line_loop;
                            }
                            try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                                if (err == error.ErrorPrinted) continue :line_loop else return err;
                            })));
                            binary_index.* += 8;
                            break;
                        }

                        break;
                    }
                }
            } else if (eql(assembly_opcode, "call")) {
                try binary.append(allocator, 0x17);
                binary_index.* += 1;
                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
            } else if (eql(assembly_opcode, "reserve")) {
                const T_int: u16 = getInt(allocator, u16, &splt_line, line_number.*, .strict, cpu_endianness) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable;
                const opt_amt: ?usize = getInt(allocator, usize, &splt_line, line_number.*, .optional, cpu_endianness) catch |err| {
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
                const T_int: u16 = getInt(allocator, u16, &splt_line, line_number.*, .strict, cpu_endianness) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable;

                var amt_of_values: usize = 0;
                var bigints = try std.ArrayListUnmanaged(BigInt).initCapacity(allocator, 8);
                defer bigints.deinit(allocator);
                defer for (bigints.items) |*bigint| bigint.deinit(allocator);

                while (true) {
                    var opt_value: ?BigInt = getBigInt(allocator, T_int, &splt_line, line_number.*, .optional) catch |err| {
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
                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getInt(allocator, u64, &splt_line, line_number.*, .incorrect, .big) catch |err| {
                    if (err == error.Incorrect) {
                        try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err2| {
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
                const T_int: u16 = getInt(allocator, u16, &splt_line, line_number.*, .strict, cpu_endianness) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable;
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
                binary_index.* += 2;

                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
                var bigint = getBigInt(allocator, T_int, &splt_line, line_number.*, .incorrect) catch |err| {
                    if (err == error.Incorrect) {
                        try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err2| {
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
                const T_int: u16 = getInt(allocator, u16, &splt_line, line_number.*, .strict, cpu_endianness) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable;
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
                binary_index.* += 2;

                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
                var bigint = getBigInt(allocator, T_int, &splt_line, line_number.*, .incorrect) catch |err| {
                    if (err == error.Incorrect) {
                        try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err2| {
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
                const T_int: u16 = getInt(allocator, u16, &splt_line, line_number.*, .strict, cpu_endianness) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable;
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
                binary_index.* += 2;

                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
                var bigint = getBigInt(allocator, T_int, &splt_line, line_number.*, .incorrect) catch |err| {
                    if (err == error.Incorrect) {
                        try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err2| {
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
                const T_int: u16 = getInt(allocator, u16, &splt_line, line_number.*, .strict, cpu_endianness) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable;
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
                binary_index.* += 2;

                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
                var bigint = getBigInt(allocator, T_int, &splt_line, line_number.*, .incorrect) catch |err| {
                    if (err == error.Incorrect) {
                        try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err2| {
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
                const T_int: u16 = getInt(allocator, u16, &splt_line, line_number.*, .strict, cpu_endianness) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable;
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
                binary_index.* += 2;

                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
                var bigint = getBigInt(allocator, T_int, &splt_line, line_number.*, .incorrect) catch |err| {
                    if (err == error.Incorrect) {
                        try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err2| {
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
                const T_int: u16 = getInt(allocator, u16, &splt_line, line_number.*, .strict, cpu_endianness) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                } orelse unreachable;
                try binary.appendSlice(allocator, &@as([2]u8, @bitCast(std.mem.nativeToBig(u16, T_int))));
                binary_index.* += 2;

                try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err| {
                    if (err == error.ErrorPrinted) continue :line_loop else return err;
                })));
                binary_index.* += 8;
                var bigint = getBigInt(allocator, T_int, &splt_line, line_number.*, .incorrect) catch |err| {
                    if (err == error.Incorrect) {
                        try binary.appendSlice(allocator, &@as([8]u8, @bitCast(getAddress(allocator, &splt_line, line_number.*, binary_index.*, alias_calls) catch |err2| {
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
            } else {
                ErrorHandler.printAssembleError("Invalid opcode", line_number.*) catch {};
                continue :line_loop;
            }

            while (splt_line.next()) |nono| {
                if (nono.len == 0) {
                    continue;
                }
                if (nono[0] == '#') continue :line_loop;
                ErrorHandler.printAssembleError("Too many arguments", line_number.*) catch {};
                continue :line_loop;
            }
        }
    }
}

const Allowed = enum(u8) {
    strict,
    incorrect,
    optional,
    both,
};

/// Returns null if allowed == .optional or allowed == .both and arg is missing
/// Returns error.Incorrect if allowed == .incorrect or allowed == .both and arg is not a number
/// Prints error on other errors
fn getInt(
    allocator: std.mem.Allocator,
    T: type,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    allowed: Allowed,
    /// What endiannes the returned integer should have
    desired_endianness: std.builtin.Endian,
) !?T {
    while (true) {
        const str = splt_line.peek() orelse {
            if (allowed == .optional or allowed == .both) {
                return null;
            } else {
                return ErrorHandler.printAssembleError("Missing argument(s)", line_number);
            }
        };

        if (str.len == 0) {
            _ = splt_line.next();
            continue;
        }
        const low_str = try String.toLowerCase(allocator, str);
        defer allocator.free(low_str);

        const int = String.intFromString(T, low_str) catch |err| {
            if ((allowed == .incorrect or allowed == .both) and err == error.NotInteger) {
                return error.Incorrect;
            } else {
                const concated = try Array.concat(allocator, u8, "Can't convert string to integer: ", @errorName(err));
                defer allocator.free(concated);
                return ErrorHandler.printAssembleError(concated, line_number);
            }
        };

        _ = splt_line.next();
        return std.mem.nativeTo(T, int, desired_endianness);
    }
}

/// Returns null if allowed == .optional or allowed == .both and arg is missing
/// Returns error.Incorrect if allowed == .incorrect or allowed == .both and arg is not a number
/// Prints error on other errors
fn getBigInt(
    allocator: std.mem.Allocator,
    byte_length: usize,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    allowed: Allowed,
) !?BigInt {
    while (true) {
        const str = splt_line.peek() orelse {
            if (allowed == .optional or allowed == .both) {
                return null;
            } else {
                return ErrorHandler.printAssembleError("Missing argument(s)", line_number);
            }
        };

        if (str.len == 0) {
            _ = splt_line.next();
            continue;
        }
        const low_str = try String.toLowerCase(allocator, str);
        defer allocator.free(low_str);

        const bigint = String.bigintFromString(allocator, byte_length, low_str) catch |err| {
            if ((allowed == .incorrect or allowed == .both) and err == error.NotInteger) {
                return error.Incorrect;
            } else {
                const concated = try Array.concat(allocator, u8, "Can't convert string to integer: ", @errorName(err));
                defer allocator.free(concated);
                return ErrorHandler.printAssembleError(concated, line_number);
            }
        };

        _ = splt_line.next();
        return bigint;
    }
}

/// Returns zero if alias is found
/// Actual address value is filled in later
fn getAddress(
    allocator: std.mem.Allocator,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    /// Should be the address/index where the address is stored
    binary_index: usize,
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
) !u64 {
    while (true) {
        const str = splt_line.peek() orelse {
            return ErrorHandler.printAssembleError("Missing argument(s)", line_number);
        };

        if (str.len == 0) {
            _ = splt_line.next();
            continue;
        }
        const low_str = try String.toLowerCase(allocator, str);
        errdefer allocator.free(low_str);

        if (low_str[0] == ':' and low_str.len > 1) {
            if (!String.containsPrintableAsciiOnly(low_str[1..])) {
                return ErrorHandler.printAssembleError("Invalid alias", line_number);
            }
            for (low_str[1..], 0..) |char, i| {
                low_str[i] = char;
            }
            try alias_calls.append(allocator, .{
                .string = try allocator.realloc(low_str, low_str.len - 1),
                .from = binary_index,
                .at_line = line_number,
            });

            _ = splt_line.next();
            return 0;
        } else if (low_str[0] == '*' and low_str.len > 1) {
            const int = std.mem.nativeToBig(u64, String.intFromString(u64, low_str[1..]) catch |err| {
                const concated = try Array.concat(allocator, u8, "Can't convert string to integer: ", @errorName(err));
                defer allocator.free(concated);
                return ErrorHandler.printAssembleError(concated, line_number);
            });

            allocator.free(low_str);
            _ = splt_line.next();
            return int;
        }

        return ErrorHandler.printAssembleError("Invalid address or alias", line_number);
    }
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn matchAliases(binary: []u8, aliases: std.StringHashMapUnmanaged(u64), alias_calls: []const AliasCall) !void {
    for (alias_calls) |*alias_call| {
        const ret = aliases.getEntry(alias_call.string);
        if (ret) |val| {
            @memcpy(
                binary[alias_call.from .. alias_call.from + 8],
                &@as([8]u8, @bitCast(std.mem.nativeToBig(@TypeOf(val.value_ptr.*), val.value_ptr.*))),
            );
        } else {
            ErrorHandler.printAssembleError("Non existant alias", alias_call.at_line) catch {};
        }
    }
}
