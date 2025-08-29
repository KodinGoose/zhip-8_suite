const std = @import("std");
const string = @import("shared").String;
const ErrorHandler = @import("error.zig").Handler;

const help_text =
    \\Usage: chip_interpreter [file_name] [args]
    \\Example: chip_interpreter pong.ch8" -Bp chip-8
    \\
    \\Args:
    \\    B [build_target]: Specify a build target
    \\    f: Fullscreen mode
    \\    i: Specify the programs starting index
    \\    h: Print this help text and exit
    \\    p: Don't terminate on encountering an error in the interpreted program. USE WITH CAUTION!!!
    \\    r [int]: How many instructions to execute
    \\    C: Client mode (Do not use this flag)
    \\
    \\Supported build targets:
    \\    chip-8
    \\    schip1.0
    \\    schip1.1
    \\    schip-modern
    \\    chip-64
    \\
;

pub const Build = enum(u8) {
    chip_8,
    schip1_0,
    schip1_1,
    schip_modern,
    chip_64,
};

/// Call deinit to free file_name
pub const Args = struct {
    file_name: ?[]const u8 = null,
    build: Build = .chip_8,
    fullscreen: bool = false,
    program_start_index: ?u64 = null,
    interpreter_panic_on_error: bool = true,
    /// How many instructions to execute
    /// Null means execute normally
    run_time: ?u64 = null,
    client_mode: bool = false,

    /// Only affects file_name
    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        if (self.file_name != null) {
            allocator.free(self.file_name.?);
            self.file_name = null;
        }
    }

    /// Safe to call even when self.file_name == null
    pub fn changeFileName(self: *@This(), allocator: std.mem.Allocator, new_name: []const u8) !void {
        if (self.file_name != null) allocator.free(self.file_name.?);
        self.file_name = try allocator.dupe(u8, new_name);
    }
};

/// Caller must call Args.deinit once done
pub fn handleArgs(allocator: std.mem.Allocator) !Args {
    var stderr_buf: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};
    var error_handler = ErrorHandler{ ._writer = stderr, ._panic_on_error = true };

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
                    'B' => {
                        const build_str = args_iter.next() orelse {
                            try error_handler.handleError("No build target specified", error.MissingArg);
                            unreachable;
                        };
                        if (std.mem.eql(u8, build_str, "chip-8")) {
                            args.build = .chip_8;
                        } else if (std.mem.eql(u8, build_str, "schip1.0")) {
                            args.build = .schip1_0;
                        } else if (std.mem.eql(u8, build_str, "schip1.1")) {
                            args.build = .schip1_1;
                        } else if (std.mem.eql(u8, build_str, "schip-modern")) {
                            args.build = .schip_modern;
                        } else if (std.mem.eql(u8, build_str, "chip-64")) {
                            args.build = .chip_64;
                        } else try error_handler.handleError("Build target not supported", error.InvalidArg);
                    },
                    'f' => args.fullscreen = !args.fullscreen,
                    'h' => {
                        try stderr.writeAll(help_text);
                        return error.HelpAsked;
                    },
                    'i' => args.program_start_index = string.intFromString(u64, args_iter.next() orelse {
                        try error_handler.handleError("No start index for the program has been specified", error.MissingArg);
                        unreachable;
                    }) catch |err| {
                        try error_handler.handleError("Invalid number for 'i' arg, number must be a 12 bit integer (0-4095)", err);
                        unreachable;
                    },
                    'p' => args.interpreter_panic_on_error = false,
                    'r' => args.run_time = string.intFromString(usize, args_iter.next() orelse {
                        try error_handler.handleError("No run time specified", error.MissingArg);
                        unreachable;
                    }) catch |err| {
                        try error_handler.handleError("Invalid number for 'r' arg, number must a 64 bit integer [0-2^64-1]", err);
                        unreachable;
                    },
                    'C' => args.client_mode = !args.client_mode,
                    else => try error_handler.handleError("Invalid argument\nJust like your mother tells you", error.InvalidArg),
                }
            }
        } else {
            try args.changeFileName(allocator, arg);
        }
    }

    if (args.file_name == null) try error_handler.handleError("No file specified", error.NoFileGiven);

    return args;
}
