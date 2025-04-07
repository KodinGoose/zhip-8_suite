const std = @import("std");
const string = @import("string.zig");

pub const Build = enum(u8) {
    chip_8,
    schip_1_0,
    schip_1_1,
};

const FileName = struct {
    _name: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !@This() {
        return .{
            ._name = try allocator.dupe(u8, name),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self._name);
    }

    pub fn changeName(self: *@This(), new_name: []const u8) !void {
        self.allocator.free(self._name);
        self._name = try self.allocator.dupe(u8, new_name);
    }

    /// Use this if new_name is already allocated and you want to give up ownership
    pub fn changeNameNoAlloc(self: *@This(), new_name: []const u8) void {
        self.allocator.free(self._name);
        self._name = new_name;
    }
};

pub const Args = struct {
    build: Build = .chip_8,
    source_file_name: FileName,
    binary_file_name: FileName,
    job: enum(u8) { assemble, de_assemble } = .assemble,
    binary_start_index: u12 = 512,
    use_assembly_like: bool = false,
    number_base_to_use: enum(u8) { binary, octal, decimal, hexadecimal } = .decimal,

    pub fn init(allocator: std.mem.Allocator) !Args {
        return .{
            .source_file_name = try FileName.init(allocator, "main.chs"),
            .binary_file_name = try FileName.init(allocator, "out.ch8"),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.source_file_name.deinit();
        self.binary_file_name.deinit();
    }
};

/// Caller must call Args.deinit once done
pub fn handleArgs(allocator: std.mem.Allocator) !Args {
    var args = try Args.init(allocator);
    errdefer args.deinit();
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.skip();

    while (args_iter.next()) |arg| {
        if (arg.len == 0) continue;
        if (arg[0] == '-') {
            for (arg[1..]) |char| {
                switch (char) {
                    'i' => args.binary_start_index = string.intFromString(u12, args_iter.next() orelse return error.NoNumberForBinaryStartIndexSpecified) catch |err| {
                        try std.io.getStdOut().writer().writeAll("Invalid number for 'i' arg, number must be a 12 bit integer (0-4095)");
                        return err;
                    },
                    'A' => args.use_assembly_like = true,
                    'a' => args.job = .assemble,
                    'd' => args.job = .de_assemble,
                    's' => try args.source_file_name.changeName(args_iter.next() orelse return error.NoSourceFileNameGiven),
                    'b' => try args.binary_file_name.changeName(args_iter.next() orelse return error.NoBinaryFileNameGiven),
                    'B' => {
                        const build_str = args_iter.next() orelse return error.NoBuildSpecified;
                        if (std.mem.eql(u8, build_str, "chip-8")) {
                            args.build = .chip_8;
                        } else if (std.mem.eql(u8, build_str, "schip1.0")) {
                            args.build = .schip_1_0;
                        } else if (std.mem.eql(u8, build_str, "schip1.1")) {
                            args.build = .schip_1_1;
                        } else return error.BroYourArgumentIsInvalid;
                    },
                    'h' => return error.HelpAsked,
                    else => return error.BroWhatIsThisArgument,
                }
            }
        } else {
            return error.BroYourArgumentIsInvalid;
        }
    }

    if (std.mem.eql(u8, args.source_file_name._name, args.binary_file_name._name)) return error.YouGaveTheSameNameForTheSourceAndBinaryFiles;

    return args;
}
