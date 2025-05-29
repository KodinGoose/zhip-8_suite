const std = @import("std");
const string = @import("string");

pub const Build = enum(u8) {
    chip_8,
    schip_1_0,
    schip_1_1,
};

const FileName = struct {
    name: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !@This() {
        return .{
            .name = try allocator.dupe(u8, name),
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        if (self.name != null) {
            allocator.free(self.name.?);
            self.name = null;
        }
    }

    pub fn changeName(self: *@This(), allocator: std.mem.Allocator, newname: []const u8) !void {
        if (self.name != null) {
            allocator.free(self.name.?);
            self.name = null;
        }
        self.name = try allocator.dupe(u8, newname);
    }
};

pub const Args = struct {
    build: Build = .chip_8,
    input_file_name: FileName = .{},
    output_file_name: FileName = .{},
    job: enum(u8) { assemble, de_assemble } = .assemble,
    binary_start_index: u12 = 512,
    use_assembly_like: bool = false,
    number_base_to_use: string.NumberBase = .hexadecimal,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.input_file_name.deinit(allocator);
        self.output_file_name.deinit(allocator);
    }
};

/// Caller must call Args.deinit once done
/// The deinit function uses the same allocator that is passed into this function
pub fn handleArgs(allocator: std.mem.Allocator) !Args {
    var args = Args{};
    errdefer args.deinit(allocator);
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.skip();

    while (args_iter.next()) |arg| {
        if (arg.len == 0) continue;
        if (arg[0] == '-') {
            for (arg[1..]) |char| {
                switch (char) {
                    's' => args.binary_start_index = string.intFromString(u12, args_iter.next() orelse return error.NoNumberForBinaryStartIndexSpecified) catch |err| {
                        try std.io.getStdOut().writer().writeAll("Invalid number for 'i' arg, number must be a 12 bit integer (0-4095)");
                        return err;
                    },
                    'A' => args.use_assembly_like = true,
                    'a' => args.job = .assemble,
                    'd' => args.job = .de_assemble,
                    'o' => try args.output_file_name.changeName(allocator, args_iter.next() orelse return error.NoOutputFileNameGiven),
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
                    'n' => {
                        const base_str = args_iter.next() orelse return error.NoBaseSpecified;
                        if (std.mem.eql(u8, base_str, "binary")) {
                            args.number_base_to_use = .binary;
                        } else if (std.mem.eql(u8, base_str, "octal")) {
                            args.number_base_to_use = .octal;
                        } else if (std.mem.eql(u8, base_str, "decimal")) {
                            args.number_base_to_use = .decimal;
                        } else if (std.mem.eql(u8, base_str, "hexadecimal")) {
                            args.number_base_to_use = .hexadecimal;
                        } else return error.BroYourArgumentIsInvalid;
                    },
                    'h' => return error.HelpAsked,
                    else => return error.BroWhatIsThisArgument,
                }
            }
        } else {
            try args.input_file_name.changeName(allocator, arg);
        }
    }

    if (args.input_file_name.name == null) return error.NoFileNameGiven;
    if (args.output_file_name.name == null)
        try args.output_file_name.changeName(allocator, if (args.job == .assemble) "out.ch8" else "main.chs");
    if (std.mem.eql(u8, args.input_file_name.name.?, args.output_file_name.name.?))
        return error.YouGaveTheSameNameForTheInputAndOutputFiles;

    return args;
}
