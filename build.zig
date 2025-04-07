const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "assembler",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = if (optimize == .Debug) false else true,
        .single_threaded = if (optimize == .Debug) false else true,
        .link_libc = if (optimize == .Debug) false else true,
    });
    b.installArtifact(exe);
}
