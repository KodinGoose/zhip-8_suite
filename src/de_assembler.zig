const std = @import("std");
const string = @import("string.zig");
const Line = @import("line.zig").Line;
const Args = @import("args.zig").Args;
const Build = @import("args.zig").Build;

pub fn translate(allocator: std.mem.Allocator, args: Args, binary: []u8) ![]const u8 {
    const lines: []Line = @alignCast(@ptrCast(binary));
    // Chip-8 binarys are always big endian encoded
    for (lines) |*line| {
        line.BigToNative();
    }
    // Revert passed in arg after use
    defer for (lines) |*line| {
        line.nativeToBigEndian();
    };

    var de_assembly = try std.ArrayList(u8).initCapacity(allocator, 4096);
    errdefer de_assembly.deinit();

    for (lines) |line| {
        try translateLine(allocator, args, line, &de_assembly);
    }

    // This was in a defer statement right after initialization but the zig compilers with versions
    // higher than 0.13 don't like it for some reason and causes a segfault at runtime
    de_assembly.shrinkAndFree(de_assembly.items.len);

    return de_assembly.items;
}

/// Directly appends to the de_assembly
fn translateLine(allocator: std.mem.Allocator, args: Args, line: Line, de_assembly: *std.ArrayList(u8)) !void {
    switch (line.opcode) {
        0x0 => {
            if (line.number_1 == 0x0 and line.number_2 == 0xE and line.number_3 == 0x0) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "clr" else "clear");
            } else if (line.number_1 == 0x0 and line.number_2 == 0xE and line.number_3 == 0xE) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "ret" else "return");
            } else if (line.number_1 == 0x0 and line.number_2 == 0xF and line.number_3 == 0xD) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "ext" else "exit");
            } else {
                try de_assembly.appendSlice(if (args.use_assembly_like) "exe " else "execute ");
                const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
                var str: []const u8 = undefined;
                str = try string.stringFromInt(allocator, args.number_base_to_use, num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            }
            try de_assembly.append('\n');
        },
        0x1 => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "jmp " else "jump ");
            const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
            var str: []const u8 = undefined;
            str = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append('\n');
        },
        0x2 => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "cal " else "call ");
            const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
            var str: []const u8 = undefined;
            str = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append('\n');
        },
        0x3 => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "seq " else "skipEqual ");
            const reg_num: u4 = line.number_1;
            try de_assembly.append('r');
            const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append(' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            var str2: []const u8 = undefined;
            str2 = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str2);
            try de_assembly.appendSlice(str2);
            try de_assembly.append('\n');
        },
        0x4 => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "sne " else "skipNotEqual ");
            const reg_num: u4 = line.number_1;
            try de_assembly.append('r');
            const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append(' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            var str2: []const u8 = undefined;
            str2 = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str2);
            try de_assembly.appendSlice(str2);
            try de_assembly.append('\n');
        },
        0x5 => {
            if (line.number_3 == 0x0) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "seq " else "skipEqual ");
                var reg_num: u4 = undefined;
                reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
                try de_assembly.append(' ');
                reg_num = line.number_2;
                try de_assembly.append('r');
                const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str2);
                try de_assembly.appendSlice(str2);
            } else {
                try writeRaw(allocator, args, de_assembly, line);
            }
            try de_assembly.append('\n');
        },
        0x6 => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "set " else "set ");
            const reg_num: u4 = line.number_1;
            try de_assembly.append('r');
            const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append(' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            var str2: []const u8 = undefined;
            str2 = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str2);
            try de_assembly.appendSlice(str2);
            try de_assembly.append('\n');
        },
        0x7 => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "add " else "add ");
            const reg_num: u4 = line.number_1;
            try de_assembly.append('r');
            const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append(' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            var str2: []const u8 = undefined;
            str2 = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str2);
            try de_assembly.appendSlice(str2);
            try de_assembly.append('\n');
        },
        0x8 => {
            switch (line.number_3) {
                0x0 => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "set " else "set ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                },
                0x1 => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "set " else "set ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                    try de_assembly.appendSlice(" or");
                },
                0x2 => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "set " else "set ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                    try de_assembly.appendSlice(" and");
                },
                0x3 => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "set " else "set ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                    try de_assembly.appendSlice(" xor");
                },
                0x4 => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "add " else "add ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                },
                0x5 => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "sub " else "subtract ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                },
                0x6 => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "rsh " else "rightShift ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                },
                0x7 => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "sub " else "subtract ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                    try de_assembly.appendSlice(" wtf");
                },
                0xE => {
                    try de_assembly.appendSlice(if (args.use_assembly_like) "lsh " else "leftShift ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append('r');
                    const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str);
                    try de_assembly.appendSlice(str);
                    try de_assembly.append(' ');
                    reg_num = line.number_2;
                    try de_assembly.append('r');
                    const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                    defer allocator.free(str2);
                    try de_assembly.appendSlice(str2);
                },
                else => {
                    try writeRaw(allocator, args, de_assembly, line);
                },
            }
            try de_assembly.append('\n');
        },
        0x9 => {
            if (line.number_3 == 0x0) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "sne " else "skipNotEqual ");
                var reg_num: u4 = undefined;
                reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
                try de_assembly.append(' ');
                reg_num = line.number_2;
                try de_assembly.append('r');
                const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str2);
                try de_assembly.appendSlice(str2);
            } else {
                try writeRaw(allocator, args, de_assembly, line);
            }
            try de_assembly.append('\n');
        },
        0xA => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "sar " else "setAddressRegister ");
            const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
            var str: []const u8 = undefined;
            str = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append('\n');
        },
        0xB => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "rjp " else "registerJump ");
            if (args.build == .chip_8) {
                const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
                var str: []const u8 = undefined;
                str = try string.stringFromInt(allocator, args.number_base_to_use, num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (args.build == .schip_1_0 or args.build == .schip_1_1) {
                const reg_num: u4 = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
                try de_assembly.append(' ');
                const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
                var str2: []const u8 = undefined;
                str2 = try string.stringFromInt(allocator, args.number_base_to_use, num);
                defer allocator.free(str2);
                try de_assembly.appendSlice(str2);
            } else unreachable;
            try de_assembly.append('\n');
        },
        0xC => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "rnd " else "random ");
            const reg_num = line.number_1;
            try de_assembly.append('r');
            const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append(' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            var str2: []const u8 = undefined;
            str2 = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str2);
            try de_assembly.appendSlice(str2);
            try de_assembly.append('\n');
        },
        0xD => {
            try de_assembly.appendSlice(if (args.use_assembly_like) "drw " else "draw ");
            var reg_num: u4 = undefined;
            reg_num = line.number_1;
            try de_assembly.append('r');
            const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
            defer allocator.free(str);
            try de_assembly.appendSlice(str);
            try de_assembly.append(' ');
            reg_num = line.number_2;
            try de_assembly.append('r');
            const str2: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
            defer allocator.free(str2);
            try de_assembly.appendSlice(str2);
            try de_assembly.append(' ');
            const num = line.number_3;
            var str3: []const u8 = undefined;
            str3 = try string.stringFromInt(allocator, args.number_base_to_use, num);
            defer allocator.free(str3);
            try de_assembly.appendSlice(str3);
            try de_assembly.append('\n');
        },
        0xE => {
            if (line.number_2 == 0x9 and line.number_3 == 0xE) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "spr " else "skipPressed ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0xA and line.number_3 == 0x1) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "snp " else "skipNotPressed ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else {
                try writeRaw(allocator, args, de_assembly, line);
            }
            try de_assembly.append('\n');
        },
        0xF => {
            if (line.number_2 == 0x0 and line.number_3 == 0x7) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "gdt " else "getDelayTimer ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x0 and line.number_3 == 0xA) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "wkr " else "waitKeyReleased ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x1 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "sdt " else "setDelayTimer ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x1 and line.number_3 == 0x8) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "sst " else "setSoundTimer ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x1 and line.number_3 == 0xE) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "aar " else "addAddressRegister ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x2 and line.number_3 == 0x9) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "saf " else "setAddressRegisterToFont ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x3 and line.number_3 == 0x0) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "saf " else "setAddressRegisterToFont ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
                try de_assembly.appendSlice(" schip");
            } else if (line.number_2 == 0x3 and line.number_3 == 0x3) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "bcd " else "binaryCodedDecimal ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x5 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "srg " else "saveRegisters ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x6 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "lrg " else "loadRegisters ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x7 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "srs " else "saveRegistersStorage ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else if (line.number_2 == 0x8 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(if (args.use_assembly_like) "lrs " else "loadRegistersStorage ");
                const reg_num = line.number_1;
                try de_assembly.append('r');
                const str: []const u8 = try string.stringFromInt(allocator, .decimal, reg_num);
                defer allocator.free(str);
                try de_assembly.appendSlice(str);
            } else {
                try writeRaw(allocator, args, de_assembly, line);
            }
            try de_assembly.append('\n');
        },
    }
}

fn writeRaw(allocator: std.mem.Allocator, args: Args, de_assembly: *std.ArrayList(u8), line: Line) !void {
    try de_assembly.appendSlice(if (args.use_assembly_like) "raw " else "rawData ");
    var str: []const u8 = undefined;
    str = try string.stringFromInt(allocator, args.number_base_to_use, line.opcode);
    defer allocator.free(str);
    try de_assembly.appendSlice(str);
    try de_assembly.append(' ');
    var str2: []const u8 = undefined;
    str2 = try string.stringFromInt(allocator, args.number_base_to_use, line.number_1);
    defer allocator.free(str2);
    try de_assembly.appendSlice(str2);
    try de_assembly.append(' ');
    var str3: []const u8 = undefined;
    str3 = try string.stringFromInt(allocator, args.number_base_to_use, line.number_2);
    defer allocator.free(str3);
    try de_assembly.appendSlice(str3);
    try de_assembly.append(' ');
    var str4: []const u8 = undefined;
    str4 = try string.stringFromInt(allocator, args.number_base_to_use, line.number_3);
    defer allocator.free(str4);
    try de_assembly.appendSlice(str4);
}
