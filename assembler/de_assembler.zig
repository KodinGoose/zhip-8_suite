const std = @import("std");
const string = @import("string");
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

    var de_assembly = try std.ArrayListUnmanaged(u8).initCapacity(allocator, 4096);
    errdefer de_assembly.deinit(allocator);

    for (lines) |line| {
        try translateLine(allocator, args, line, &de_assembly);
    }

    // This was in a defer statement right after initialization but the zig compilers with versions
    // higher than 0.13 don't like it for some reason and causes a segfault at runtime
    de_assembly.shrinkAndFree(allocator, de_assembly.items.len);

    return de_assembly.items;
}

/// Directly appends to the de_assembly
fn translateLine(allocator: std.mem.Allocator, args: Args, line: Line, de_assembly: *std.ArrayListUnmanaged(u8)) !void {
    var buffer: [4 + 2]u8 = [1]u8{undefined} ** 6;
    switch (line.opcode) {
        0x0 => {
            if (line.number_1 == 0x0 and line.number_2 == 0xE and line.number_3 == 0x0) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "clr" else "clear");
            } else if (line.number_1 == 0x0 and line.number_2 == 0xE and line.number_3 == 0xE) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "ret" else "return");
            } else if (line.number_1 == 0x0 and line.number_2 == 0xF and line.number_3 == 0xD) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "ext" else "exit");
            } else {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "exe " else "execute ");
                const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
                try de_assembly.appendSlice(allocator, str);
            }
            try de_assembly.append(allocator, '\n');
        },
        0x1 => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "jmp " else "jump ");
            const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, '\n');
        },
        0x2 => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "cal " else "call ");
            const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, '\n');
        },
        0x3 => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "seq " else "skipEqual ");
            const reg_num: u4 = line.number_1;
            try de_assembly.append(allocator, 'r');
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, ' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str2);
            try de_assembly.append(allocator, '\n');
        },
        0x4 => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "sne " else "skipNotEqual ");
            const reg_num: u4 = line.number_1;
            try de_assembly.append(allocator, 'r');
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, ' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str2);
            try de_assembly.append(allocator, '\n');
        },
        0x5 => {
            if (line.number_3 == 0x0) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "seq " else "skipEqual ");
                var reg_num: u4 = undefined;
                reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
                try de_assembly.append(allocator, ' ');
                reg_num = line.number_2;
                try de_assembly.append(allocator, 'r');
                const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str2);
            } else {
                try writeRaw(allocator, &buffer, args, de_assembly, line);
            }
            try de_assembly.append(allocator, '\n');
        },
        0x6 => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "set " else "set ");
            const reg_num: u4 = line.number_1;
            try de_assembly.append(allocator, 'r');
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, ' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str2);
            try de_assembly.append(allocator, '\n');
        },
        0x7 => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "add " else "add ");
            const reg_num: u4 = line.number_1;
            try de_assembly.append(allocator, 'r');
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, ' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str2);
            try de_assembly.append(allocator, '\n');
        },
        0x8 => {
            switch (line.number_3) {
                0x0 => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "set " else "set ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                },
                0x1 => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "set " else "set ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                    try de_assembly.appendSlice(allocator, " or");
                },
                0x2 => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "set " else "set ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                    try de_assembly.appendSlice(allocator, " and");
                },
                0x3 => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "set " else "set ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                    try de_assembly.appendSlice(allocator, " xor");
                },
                0x4 => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "add " else "add ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                },
                0x5 => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "sub " else "subtract ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                },
                0x6 => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "rsh " else "rightShift ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                },
                0x7 => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "sub " else "subtract ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                    try de_assembly.appendSlice(allocator, " wtf");
                },
                0xE => {
                    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "lsh " else "leftShift ");
                    var reg_num: u4 = undefined;
                    reg_num = line.number_1;
                    try de_assembly.append(allocator, 'r');
                    const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str);
                    try de_assembly.append(allocator, ' ');
                    reg_num = line.number_2;
                    try de_assembly.append(allocator, 'r');
                    const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                    try de_assembly.appendSlice(allocator, str2);
                },
                else => {
                    try writeRaw(allocator, &buffer, args, de_assembly, line);
                },
            }
            try de_assembly.append(allocator, '\n');
        },
        0x9 => {
            if (line.number_3 == 0x0) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "sne " else "skipNotEqual ");
                var reg_num: u4 = undefined;
                reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
                try de_assembly.append(allocator, ' ');
                reg_num = line.number_2;
                try de_assembly.append(allocator, 'r');
                const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str2);
            } else {
                try writeRaw(allocator, &buffer, args, de_assembly, line);
            }
            try de_assembly.append(allocator, '\n');
        },
        0xA => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "sar " else "setAddressRegister ");
            const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, '\n');
        },
        0xB => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "rjp " else "registerJump ");
            if (args.build == .chip_8) {
                const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
                try de_assembly.appendSlice(allocator, str);
            } else if (args.build == .schip_1_0 or args.build == .schip_1_1) {
                const reg_num: u4 = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
                try de_assembly.append(allocator, ' ');
                const num: u12 = (@as(u12, line.number_1) << 8) + (@as(u12, line.number_2) << 4) + line.number_3;
                const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
                try de_assembly.appendSlice(allocator, str2);
            } else unreachable;
            try de_assembly.append(allocator, '\n');
        },
        0xC => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "rnd " else "random ");
            const reg_num = line.number_1;
            try de_assembly.append(allocator, 'r');
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, ' ');
            const num: u8 = (@as(u8, line.number_2) << 4) + line.number_3;
            const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str2);
            try de_assembly.append(allocator, '\n');
        },
        0xD => {
            try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "drw " else "draw ");
            var reg_num: u4 = undefined;
            reg_num = line.number_1;
            try de_assembly.append(allocator, 'r');
            const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
            try de_assembly.appendSlice(allocator, str);
            try de_assembly.append(allocator, ' ');
            reg_num = line.number_2;
            try de_assembly.append(allocator, 'r');
            const str2 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
            try de_assembly.appendSlice(allocator, str2);
            try de_assembly.append(allocator, ' ');
            const num = line.number_3;
            const str3 = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, num);
            try de_assembly.appendSlice(allocator, str3);
            try de_assembly.append(allocator, '\n');
        },
        0xE => {
            if (line.number_2 == 0x9 and line.number_3 == 0xE) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "spr " else "skipPressed ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0xA and line.number_3 == 0x1) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "snp " else "skipNotPressed ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else {
                try writeRaw(allocator, &buffer, args, de_assembly, line);
            }
            try de_assembly.append(allocator, '\n');
        },
        0xF => {
            if (line.number_2 == 0x0 and line.number_3 == 0x7) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "gdt " else "getDelayTimer ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x0 and line.number_3 == 0xA) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "wkr " else "waitKeyReleased ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x1 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "sdt " else "setDelayTimer ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x1 and line.number_3 == 0x8) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "sst " else "setSoundTimer ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x1 and line.number_3 == 0xE) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "aar " else "addAddressRegister ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x2 and line.number_3 == 0x9) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "saf " else "setAddressRegisterToFont ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x3 and line.number_3 == 0x0) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "saf " else "setAddressRegisterToFont ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
                try de_assembly.appendSlice(allocator, " schip");
            } else if (line.number_2 == 0x3 and line.number_3 == 0x3) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "bcd " else "binaryCodedDecimal ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x5 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "srg " else "saveRegisters ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x6 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "lrg " else "loadRegisters ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
            } else if (line.number_2 == 0x7 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "srg " else "saveRegisters ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
                try de_assembly.appendSlice(allocator, " storage");
            } else if (line.number_2 == 0x8 and line.number_3 == 0x5) {
                try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "lrg " else "loadRegisters ");
                const reg_num = line.number_1;
                try de_assembly.append(allocator, 'r');
                const str = string.stringFromIntNoAlloc(&buffer, args.number_base_to_use, reg_num);
                try de_assembly.appendSlice(allocator, str);
                try de_assembly.appendSlice(allocator, " storage");
            } else {
                try writeRaw(allocator, &buffer, args, de_assembly, line);
            }
            try de_assembly.append(allocator, '\n');
        },
    }
}

fn writeRaw(allocator: std.mem.Allocator, buffer: []u8, args: Args, de_assembly: *std.ArrayListUnmanaged(u8), line: Line) !void {
    try de_assembly.appendSlice(allocator, if (args.use_assembly_like) "raw " else "rawData ");
    const str = string.stringFromIntNoAlloc(buffer, args.number_base_to_use, line.opcode);
    try de_assembly.appendSlice(allocator, str);
    try de_assembly.append(allocator, ' ');
    const str2 = string.stringFromIntNoAlloc(buffer, args.number_base_to_use, line.number_1);
    try de_assembly.appendSlice(allocator, str2);
    try de_assembly.append(allocator, ' ');
    const str3 = string.stringFromIntNoAlloc(buffer, args.number_base_to_use, line.number_2);
    try de_assembly.appendSlice(allocator, str3);
    try de_assembly.append(allocator, ' ');
    const str4 = string.stringFromIntNoAlloc(buffer, args.number_base_to_use, line.number_3);
    try de_assembly.appendSlice(allocator, str4);
}
