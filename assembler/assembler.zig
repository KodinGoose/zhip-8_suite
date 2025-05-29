const std = @import("std");
const string = @import("string");
const error_handler = @import("error.zig");
const Line = @import("line.zig").Line;

/// Returned list is allocated and owned by the caller
pub fn translate(allocator: std.mem.Allocator, binary_start_index: u12, assembly_code: []u8) ![]Line {
    var binary = try std.ArrayList(Line).initCapacity(allocator, 2048);
    errdefer binary.deinit();
    var aliases = std.StringHashMapUnmanaged(u12){};
    defer aliases.deinit(allocator);

    const assembly_code_copy = try allocator.dupe(u8, assembly_code);
    defer allocator.free(assembly_code_copy);
    for (assembly_code_copy) |*char| {
        if (char.* == '\r') char.* = ' ';
    }
    var code_splt = std.mem.splitScalar(u8, assembly_code_copy, '\n');
    var line_number: usize = 1;
    var binary_index: u12 = binary_start_index;
    while (code_splt.next()) |line_str| {
        checkAndGetAlias(allocator, line_str, binary_index, &aliases, line_number) catch |err| {
            if (err == error.EmptyLine) {
                line_number += 1;
                continue;
            } else if (err == error.AssembleError) {
                return error.AliasError;
            }
            return err;
        };
        line_number += 1;
        binary_index = std.math.add(@TypeOf(binary_index), binary_index, 2) catch |err|
            return error_handler.printReturnError(err, "Largest binary supported is 4 kilobytes (4096 bytes)");
    }
    code_splt.reset();
    line_number = 1;
    binary_index = binary_start_index;
    while (code_splt.next()) |line_str| {
        var line = Line{};
        line = translateLine(line_str, &aliases, line_number) catch |err| blk: {
            if (err == error.EmptyLine) {
                line_number += 1;
                continue;
            } else if (err == error.AssembleError) {
                break :blk .{ .number_3 = 0xF, .number_2 = 0xF, .number_1 = 0xF, .opcode = 0xF };
            } else {
                return err;
            }
        };
        try binary.append(line);
        line_number += 1;
        binary_index = std.math.add(@TypeOf(binary_index), binary_index, 2) catch |err|
            return error_handler.printReturnError(err, "Largest binary supported is 4 kilobytes (4096 bytes)");
    }

    // Chip-8 uses big endian
    // This ensures that the outputted binary uses big endian
    for (binary.items) |*line| {
        line.nativeToBigEndian();
    }

    binary.shrinkAndFree(binary.items.len);

    return binary.items;
}

/// This function returns error.EmptyLine if the line is empty or has a comment before an alias or opcode
/// If an error is encountered in the assembly_line assemble_error is returned
fn checkAndGetAlias(
    allocator: std.mem.Allocator,
    assembly_line: []const u8,
    binary_index: u12,
    aliases: *std.StringHashMapUnmanaged(u12),
    line_number: usize,
) !void {
    var line_splt = std.mem.splitScalar(u8, assembly_line, ' ');

    while (line_splt.next()) |str| {
        if (str.len == 0) {
            continue;
        }

        if (str[0] == '#') {
            return error.EmptyLine;
        } else if (str[str.len - 1] == ':') {
            if (!string.containsLettersOnly(str[0 .. str.len - 1]))
                return error_handler.printAssembleError("Aliases can only contain letters", line_number);
            const ret = aliases.getEntry(str[0 .. str.len - 1]);
            if (ret) |_| {
                return error_handler.printAssembleError("Duplicate alias", line_number);
            } else {
                try aliases.put(allocator, str[0 .. str.len - 1], binary_index);
                continue;
            }
        }
        return;
    }
}

/// This function returns error.EmptyLine if the line is empty or has a comment before an alias or opcode
/// This error is supposed to be "handled" by ignoring this line
fn translateLine(
    assembly_line: []const u8,
    aliases: *std.StringHashMapUnmanaged(u12),
    line_number: usize,
) !Line {
    var line_splt = std.mem.splitScalar(u8, assembly_line, ' ');
    var binary_line = Line{};

    while (line_splt.next()) |opcode| {
        if (opcode.len == 0) {
            continue;
        }

        if (opcode[0] == '#') {
            return error.EmptyLine;
        } else if (opcode[opcode.len - 1] == ':') {
            if (!string.containsLettersOnly(opcode[0 .. opcode.len - 1]))
                return error_handler.printAssembleError("Aliases can only contain letters", line_number);
            continue;
        }

        if (std.mem.eql(u8, opcode, "exe") or std.mem.eql(u8, opcode, "execute")) {
            binary_line.opcode = 0x0;
            getAddress(&line_splt, &binary_line) catch {
                try getAlias(&line_splt, &binary_line, aliases.*);
            };
        } else if (std.mem.eql(u8, opcode, "clr") or std.mem.eql(u8, opcode, "clear")) {
            binary_line = @bitCast(@as(u16, 0x00E0));
        } else if (std.mem.eql(u8, opcode, "ret") or std.mem.eql(u8, opcode, "return")) {
            binary_line = @bitCast(@as(u16, 0x00EE));
        } else if (std.mem.eql(u8, opcode, "ext") or std.mem.eql(u8, opcode, "exit")) {
            binary_line = @bitCast(@as(u16, 0x00FD));
        } else if (std.mem.eql(u8, opcode, "jmp") or std.mem.eql(u8, opcode, "jump")) {
            binary_line.opcode = 0x1;
            getAddress(&line_splt, &binary_line) catch {
                try getAlias(&line_splt, &binary_line, aliases.*);
            };
        } else if (std.mem.eql(u8, opcode, "cal") or std.mem.eql(u8, opcode, "call")) {
            binary_line.opcode = 0x2;
            getAddress(&line_splt, &binary_line) catch {
                try getAlias(&line_splt, &binary_line, aliases.*);
            };
        } else if (std.mem.eql(u8, opcode, "seq") or std.mem.eql(u8, opcode, "skipEqual")) {
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.opcode = 0x3;
            get8BitNumber(&line_splt, &binary_line) catch {
                binary_line.number_2 = try getRegister(&line_splt);
                // Technically not required
                binary_line.number_3 = 0x0;
                binary_line.opcode = 0x5;
            };
        } else if (std.mem.eql(u8, opcode, "sne") or std.mem.eql(u8, opcode, "skipNotEqual")) {
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.opcode = 0x4;
            get8BitNumber(&line_splt, &binary_line) catch {
                binary_line.number_2 = try getRegister(&line_splt);
                binary_line.opcode = 0x9;
            };
        } else if (std.mem.eql(u8, opcode, "set")) blk: {
            binary_line.number_1 = try getRegister(&line_splt);
            get8BitNumber(&line_splt, &binary_line) catch {
                binary_line.number_2 = try getRegister(&line_splt);
                binary_line.opcode = 0x8;
                // No argument given here is valid
                while (line_splt.next()) |arg| {
                    if (arg.len == 0) {
                        continue;
                    }
                    if (std.mem.eql(u8, arg, "or")) {
                        binary_line.number_3 = 0x1;
                    } else if (std.mem.eql(u8, arg, "and")) {
                        binary_line.number_3 = 0x2;
                    } else if (std.mem.eql(u8, arg, "xor")) {
                        binary_line.number_3 = 0x3;
                    } else {
                        return error_handler.printAssembleError("Invalid argument. Valid arguments are: or, and, xor", line_number);
                    }
                }
                break :blk;
            };
            binary_line.opcode = 0x6;
        } else if (std.mem.eql(u8, opcode, "add")) blk: {
            binary_line.number_1 = try getRegister(&line_splt);
            get8BitNumber(&line_splt, &binary_line) catch {
                binary_line.number_2 = try getRegister(&line_splt);
                binary_line.number_3 = 0x4;
                binary_line.opcode = 0x8;
                break :blk;
            };
            binary_line.opcode = 0x7;
        } else if (std.mem.eql(u8, opcode, "sub") or std.mem.eql(u8, opcode, "subtract")) {
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = try getRegister(&line_splt);
            binary_line.number_3 = if (try getModifier(&line_splt, "wtf")) 0x7 else 0x5;
            binary_line.opcode = 0x8;
        } else if (std.mem.eql(u8, opcode, "rsh") or std.mem.eql(u8, opcode, "rightShift")) {
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = try getRegister(&line_splt);
            binary_line.number_3 = 0x6;
            binary_line.opcode = 0x8;
        } else if (std.mem.eql(u8, opcode, "lsh") or std.mem.eql(u8, opcode, "leftShift")) {
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = try getRegister(&line_splt);
            binary_line.number_3 = 0xE;
            binary_line.opcode = 0x8;
        } else if (std.mem.eql(u8, opcode, "sar") or std.mem.eql(u8, opcode, "setAddressRegister")) {
            try getAddress(&line_splt, &binary_line);
            binary_line.opcode = 0xA;
        } else if (std.mem.eql(u8, opcode, "rjp") or std.mem.eql(u8, opcode, "registerJump")) blk: {
            binary_line.opcode = 0xB;
            getAddress(&line_splt, &binary_line) catch {
                getAlias(&line_splt, &binary_line, aliases.*) catch {
                    binary_line.number_1 = try getRegister(&line_splt);
                    try get8BitNumber(&line_splt, &binary_line);
                    break :blk;
                };
                // heh?
                break :blk;
            };
        } else if (std.mem.eql(u8, opcode, "rnd") or std.mem.eql(u8, opcode, "random")) {
            binary_line.opcode = 0xC;
            binary_line.number_1 = try getRegister(&line_splt);
            try get8BitNumber(&line_splt, &binary_line);
        } else if (std.mem.eql(u8, opcode, "drw") or std.mem.eql(u8, opcode, "draw")) {
            binary_line.opcode = 0xD;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = try getRegister(&line_splt);
            binary_line.number_3 = try get4BitNumber(&line_splt);
        } else if (std.mem.eql(u8, opcode, "spr") or std.mem.eql(u8, opcode, "skipPressed")) {
            binary_line.opcode = 0xE;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = 0x9;
            binary_line.number_3 = 0xE;
        } else if (std.mem.eql(u8, opcode, "snp") or std.mem.eql(u8, opcode, "skipNotPressed")) {
            binary_line.opcode = 0xE;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = 0xA;
            binary_line.number_3 = 0x1;
        } else if (std.mem.eql(u8, opcode, "gdt") or std.mem.eql(u8, opcode, "getDelayTimer")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = 0x0;
            binary_line.number_3 = 0x7;
        } else if (std.mem.eql(u8, opcode, "wkr") or std.mem.eql(u8, opcode, "waitKeyReleased")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = 0x0;
            binary_line.number_3 = 0xA;
        } else if (std.mem.eql(u8, opcode, "sdt") or std.mem.eql(u8, opcode, "setDelayTimer")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = 0x1;
            binary_line.number_3 = 0x5;
        } else if (std.mem.eql(u8, opcode, "sst") or std.mem.eql(u8, opcode, "setSoundTimer")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = 0x1;
            binary_line.number_3 = 0x8;
        } else if (std.mem.eql(u8, opcode, "aar") or std.mem.eql(u8, opcode, "addAddressRegister")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = 0x1;
            binary_line.number_3 = 0xE;
        } else if (std.mem.eql(u8, opcode, "saf") or std.mem.eql(u8, opcode, "setAddressRegisterToFont")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            if (try getModifier(&line_splt, "schip")) {
                binary_line.number_2 = 0x3;
                binary_line.number_3 = 0x0;
            } else {
                binary_line.number_2 = 0x2;
                binary_line.number_3 = 0x9;
            }
        } else if (std.mem.eql(u8, opcode, "bcd") or std.mem.eql(u8, opcode, "binaryCodedDecimal")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = 0x3;
            binary_line.number_3 = 0x3;
        } else if (std.mem.eql(u8, opcode, "srg") or std.mem.eql(u8, opcode, "saveRegisters")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = if (try getModifier(&line_splt, "storage")) 0x7 else 0x5;
            binary_line.number_3 = 0x5;
        } else if (std.mem.eql(u8, opcode, "lrg") or std.mem.eql(u8, opcode, "loadRegisters")) {
            binary_line.opcode = 0xF;
            binary_line.number_1 = try getRegister(&line_splt);
            binary_line.number_2 = if (try getModifier(&line_splt, "storage")) 0x8 else 0x6;
            binary_line.number_3 = 0x5;
        } else if (std.mem.eql(u8, opcode, "raw") or std.mem.eql(u8, opcode, "rawData")) {
            binary_line.opcode = try get4BitNumber(&line_splt);
            binary_line.number_1 = try get4BitNumber(&line_splt);
            binary_line.number_2 = try get4BitNumber(&line_splt);
            binary_line.number_3 = try get4BitNumber(&line_splt);
        } else {
            return error_handler.printAssembleError("Invalid opcode", line_number);
        }
        while (line_splt.next()) |nono| {
            if (nono.len == 0) {
                continue;
            }
            if (nono[0] == '#') break;
            return error.Too_Many_Arguments;
        }
        return binary_line;
    } else return error.EmptyLine;
}

fn getAddress(line_splt: *std.mem.SplitIterator(u8, .scalar), binary_line: *Line) !void {
    while (true) {
        const address = line_splt.peek() orelse return error.No_Arguments;
        if (address.len == 0) {
            _ = line_splt.next();
            continue;
        }

        const num = try string.intFromString(u12, address);
        binary_line.number_3 = @truncate(num >> 0);
        binary_line.number_2 = @truncate(num >> 4);
        binary_line.number_1 = @truncate(num >> 8);
        _ = line_splt.next();
        return;
    }
}

fn get8BitNumber(line_splt: *std.mem.SplitIterator(u8, .scalar), binary_line: *Line) !void {
    while (true) {
        const number_str = line_splt.peek() orelse return error.No_Arguments;
        if (number_str.len == 0) {
            _ = line_splt.next();
            continue;
        }

        const num = try string.intFromString(u8, number_str);
        binary_line.number_3 = @truncate(num >> 0);
        binary_line.number_2 = @truncate(num >> 4);
        _ = line_splt.next();
        return;
    }
}

fn get4BitNumber(line_splt: *std.mem.SplitIterator(u8, .scalar)) !u4 {
    while (true) {
        const number_str = line_splt.peek() orelse return error.No_Arguments;
        if (number_str.len == 0) {
            _ = line_splt.next();
            continue;
        }

        const num = try string.intFromString(u4, number_str);
        _ = line_splt.next();
        return num;
    }
}

/// Return the registers number
fn getRegister(line_splt: *std.mem.SplitIterator(u8, .scalar)) !u4 {
    while (true) {
        const register_str = line_splt.peek() orelse return error.No_Arguments;
        if (register_str.len == 0) {
            _ = line_splt.next();
            continue;
        }

        if (register_str[0] != 'r' or register_str.len < 2) return error.NotRegister;
        const num = try string.intFromString(u4, register_str[1..]);
        _ = line_splt.next();
        return num;
    }
}

fn getAlias(line_splt: *std.mem.SplitIterator(u8, .scalar), binary_line: *Line, aliases: std.StringHashMapUnmanaged(u12)) !void {
    while (true) {
        const str = line_splt.peek() orelse return error.No_Arguments;
        if (str.len == 0) {
            _ = line_splt.next();
            continue;
        }
        if (str[0] != ':' or str.len < 2) return error.NotAlias;
        if (!string.containsLettersOnly(str[1..])) return error.Alias_Can_Only_Contain_Letters;
        const address = aliases.get(str[1..]) orelse return error.Non_Existant_Alias;
        binary_line.number_3 = @truncate(address >> 0);
        binary_line.number_2 = @truncate(address >> 4);
        binary_line.number_1 = @truncate(address >> 8);
        _ = line_splt.next();
        return;
    }
}

/// Returns true if the modifier arg is passed in and false otherwise
fn getModifier(line_splt: *std.mem.SplitIterator(u8, .scalar), modifier_str: []const u8) !bool {
    while (line_splt.next()) |modifier| {
        if (modifier.len == 0) {
            continue;
        }
        if (std.mem.eql(u8, modifier, modifier_str)) {
            return true;
        }
        return error.Invalid_Argument;
    }
    return false;
}

/// Returns true if the modifier arg is passed in and false otherwise
/// Uses .peek() instead of .next()
fn getModifierPeek(line_splt: *std.mem.SplitIterator(u8, .scalar), modifier_str: []const u8) !bool {
    while (true) {
        if (line_splt.peek().len == 0) {
            _ = line_splt.next();
            continue;
        }
        if (std.mem.eql(u8, line_splt.peek(), modifier_str)) {
            return true;
        }
        return error.Invalid_Argument;
    }
    return false;
}
