const std = @import("std");
const builtin = @import("builtin");

const Array = @import("shared").Array;
const BigInt = @import("shared").BigInt;
const String = @import("shared").String;

const ErrorHandler = @import("../error.zig");
const Args = @import("../args.zig").Args;

const cpu_endianness = builtin.cpu.arch.endian();

pub const AliasCall = struct {
    /// Name of the alias
    /// Assumed to be allocated
    string: []u8,
    /// The actual binary index where the call is made from
    from: usize,
    at_line: usize,
    treat_as_number: bool = false,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.string);
    }
};

/// Returns assembled code
pub fn assemble(allocator: std.mem.Allocator, error_writer: *std.Io.Writer, args: Args, code: []u8, AddressT: type, instructionAssembler: fn (
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    splt_code: *std.mem.SplitIterator(u8, .scalar),
    line_number: *usize,
    binary_index: *usize,
    aliases: *std.StringHashMapUnmanaged(AddressT),
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
    binary: *std.ArrayListUnmanaged(u8),
) anyerror!void) ![]u8 {
    if (args.binary_start_index != null) if (args.binary_start_index.? > std.math.maxInt(usize)) {
        return ErrorHandler.printReturnError(error_writer, error.PEBCAK, "Your architecture cannot index that big of a number");
    };
    var binary_index: usize = if (args.build == .chip_64) 0 else 0x200;
    if (args.binary_start_index != null) binary_index = @intCast(args.binary_start_index.?);

    var binary = try std.ArrayListUnmanaged(u8).initCapacity(allocator, @max(1024 * 256, binary_index));
    try binary.resize(allocator, binary_index);
    errdefer binary.deinit(allocator);
    var aliases = std.StringHashMapUnmanaged(AddressT){};
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
    try instructionAssembler(allocator, error_writer, &splt_code, &line_number, &binary_index, &aliases, &alias_calls, &binary);

    try matchAliases(allocator, error_writer, binary.items, AddressT, aliases, alias_calls.items);

    if (binary.items.len >= std.math.maxInt(AddressT)) {
        ErrorHandler.printAssembleWarning(error_writer, "Binary size larger than maximum indexable range");
    }
    binary.shrinkAndFree(allocator, binary.items.len);
    return binary.items;
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
pub fn getStr(
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
pub fn getStrPeek(
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

const AllowAliasAsNumber = enum(u1) {
    allow,
    dont_allow,
};

/// Returns null if allowed == .optional and arg is missing
/// Returns error.Incorrect if allowed == .incorrect and arg is not a number
/// Prints error on other errors
/// return_T's bitsize must be a multiple of 8
pub fn getInt(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    T: type,
    /// Returned integer is casted to this type
    /// Bit size must be >= to bit size of T
    ReturnT: type,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    AddressT: type,
    real_binary_index: usize,
    aliases: *std.StringHashMapUnmanaged(AddressT),
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
    allowed: Allowed,
    allow_alias_as_number: AllowAliasAsNumber,
    /// What endiannes the returned integer should have
    desired_endianness: std.builtin.Endian,
) !?ReturnT {
    try checkForAliases(allocator, error_writer, splt_line, line_number, AddressT, aliases, @truncate(real_binary_index));

    const str = (try getStrPeek(allocator, error_writer, splt_line, line_number, allowed)) orelse return null;
    errdefer allocator.free(str);

    if (str[0] == '*') {
        if (allow_alias_as_number == .dont_allow) {
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
            .from = real_binary_index,
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
    return std.mem.nativeTo(ReturnT, @intCast(int), desired_endianness);
}

/// Returns null if allowed == .optional or allowed == .both and arg is missing
/// Returns error.Incorrect if allowed == .incorrect or allowed == .both and arg is not a number
/// Prints error on other errors
pub fn getBigInt(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    byte_length: usize,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    AddressT: type,
    real_binary_index: usize,
    aliases: *std.StringHashMapUnmanaged(AddressT),
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
    allowed: Allowed,
    allow_alias_as_number: AllowAliasAsNumber,
) !?BigInt {
    try checkForAliases(allocator, error_writer, splt_line, line_number, AddressT, aliases, @truncate(real_binary_index));

    const str = (try getStrPeek(allocator, error_writer, splt_line, line_number, allowed)) orelse return null;
    errdefer allocator.free(str);

    if (str[0] == '*') {
        if (allow_alias_as_number == .dont_allow) {
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
            .from = real_binary_index,
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
/// return_T's bitsize must be a multiple of 8
pub fn getAddress(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    /// Returned address is casted to this type
    /// Bit size must be >= to bit size of T
    ReturnT: type,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    AddressT: type,
    /// Should be the address/index where the address is stored
    real_binary_index: usize,
    aliases: *std.StringHashMapUnmanaged(AddressT),
    alias_calls: *std.ArrayListUnmanaged(AliasCall),
) !ReturnT {
    try checkForAliases(allocator, error_writer, splt_line, line_number, AddressT, aliases, @truncate(real_binary_index));

    const str = (try getStrPeek(allocator, error_writer, splt_line, line_number, .strict)).?;
    errdefer allocator.free(str);

    if (str[0] == ':' and str.len > 1) {
        const int = std.mem.nativeToBig(ReturnT, @intCast(String.intFromString(AddressT, str[1..]) catch {
            if (!String.containsLettersOnly(str[1..2]) or !String.containsPrintableAsciiOnly(str[2..])) {
                return ErrorHandler.printAssembleError(error_writer, "Invalid alias or address", line_number);
            }
            for (str[1..], 0..) |char, i| {
                str[i] = char;
            }
            try alias_calls.append(allocator, .{
                .string = try allocator.realloc(str, str.len - 1),
                .from = real_binary_index,
                .at_line = line_number,
            });

            _ = splt_line.next();
            return 0;
        }));

        allocator.free(str);
        _ = splt_line.next();
        return int;
    }

    return ErrorHandler.printAssembleError(error_writer, "Not an address or alias", line_number);
}

const SkipLine = enum(u1) { no_skip, skip };

pub fn checkForComments(splt_line: *std.mem.SplitIterator(u8, .scalar)) SkipLine {
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

pub fn checkForAliases(
    allocator: std.mem.Allocator,
    error_writer: *std.Io.Writer,
    splt_line: *std.mem.SplitIterator(u8, .scalar),
    line_number: usize,
    AddressT: type,
    aliases: *std.StringHashMapUnmanaged(AddressT),
    binary_index: AddressT,
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

pub fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn matchAliases(allocator: std.mem.Allocator, error_writer: *std.Io.Writer, binary: []u8, AddressT: type, aliases: std.StringHashMapUnmanaged(AddressT), alias_calls: []const AliasCall) !void {
    for (alias_calls) |*alias_call| {
        const ret = aliases.getEntry(alias_call.string);
        if (ret) |val| {
            if (@bitSizeOf(AddressT) % 8 == 0) {
                @memcpy(
                    binary[alias_call.from .. alias_call.from + @bitSizeOf(AddressT) / 8],
                    &@as([@bitSizeOf(AddressT) / 8]u8, @bitCast(std.mem.nativeToBig(@TypeOf(val.value_ptr.*), val.value_ptr.*))),
                );
            } else {
                var tmp = binary[alias_call.from];
                var val_bytes = std.mem.asBytes(val.value_ptr);
                if (cpu_endianness == .big) {
                    @memcpy(
                        binary[alias_call.from .. alias_call.from + @bitSizeOf(AddressT) / 8 + 1],
                        val_bytes[0 .. @bitSizeOf(AddressT) / 8 + 1],
                    );
                } else {
                    var reversed_val_bytes = try Array.reverseArrayAlloc(allocator, u8, val_bytes);
                    defer allocator.free(reversed_val_bytes);
                    @memcpy(
                        binary[alias_call.from .. alias_call.from + @bitSizeOf(AddressT) / 8 + 1],
                        reversed_val_bytes[val_bytes.len - (@bitSizeOf(AddressT) / 8 + 1) ..],
                    );
                }
                // @memcpy(
                //     binary[alias_call.address .. alias_call.address + @bitSizeOf(AddressT) / 8 + 1],
                //     &@as([@bitSizeOf(AddressT) / 8 + 1]u8, @bitCast(std.mem.nativeToBig(@TypeOf(val.value_ptr.*), val.value_ptr.*))),
                // );
                tmp &= 0xF0;
                binary[alias_call.from] &= 0x0F;
                binary[alias_call.from] |= tmp;
            }
        } else {
            ErrorHandler.printAssembleError(error_writer, "Non existant alias", alias_call.at_line) catch {};
        }
    }
}
