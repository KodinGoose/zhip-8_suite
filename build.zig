const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared_module = b.createModule(.{
        .root_source_file = b.path("shared/root.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = if (optimize == .Debug) false else true,
        .strip = if (optimize == .Debug) false else true,
    });

    const sdl_bindings_module = b.createModule(.{
        .root_source_file = b.path("sdl_bindings/root.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = if (optimize == .Debug) false else true,
        .strip = if (optimize == .Debug) false else true,
    });
    if (target.result.os.tag == .windows) {
        sdl_bindings_module.addIncludePath(b.path("windows_sdl/include/"));
    }

    const assembler_module = b.createModule(.{
        .root_source_file = b.path("assembler/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = if (optimize == .Debug) false else true,
        .strip = if (optimize == .Debug) false else true,
        .link_libc = if (optimize == .Debug) false else true,
    });
    const interpreter_module = b.createModule(.{
        .root_source_file = b.path("interpreter/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = if (optimize == .Debug) false else true,
        .strip = if (optimize == .Debug) false else true,
        .link_libc = true,
    });
    const gui_module = b.createModule(.{
        .root_source_file = b.path("gui/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = if (optimize == .Debug) false else true,
        .strip = if (optimize == .Debug) false else true,
        .link_libc = true,
    });

    assembler_module.addImport("shared", shared_module);
    interpreter_module.addImport("shared", shared_module);
    interpreter_module.addImport("sdl_bindings", sdl_bindings_module);
    gui_module.addImport("shared", shared_module);
    gui_module.addImport("sdl_bindings", sdl_bindings_module);

    const assembler = b.addExecutable(.{
        .name = "assembler",
        .root_module = assembler_module,
    });
    const interpreter = b.addExecutable(.{
        .name = "interpreter",
        .root_module = interpreter_module,
    });
    const gui = b.addExecutable(.{
        .name = "gui",
        .root_module = gui_module,
    });

    if (target.result.os.tag == .windows) {
        interpreter_module.addLibraryPath(b.path("windows_sdl/lib/"));
        interpreter_module.addLibraryPath(b.path("windows_sdl/bin/"));
        gui_module.addLibraryPath(b.path("windows_sdl/lib/"));
        gui_module.addLibraryPath(b.path("windows_sdl/bin/"));
    }

    interpreter.linkSystemLibrary("SDL3");
    gui.linkSystemLibrary("SDL3");
    gui.linkSystemLibrary("SDL3_ttf");

    b.installArtifact(assembler);
    b.installArtifact(interpreter);
    b.installArtifact(gui);
    if (target.result.os.tag == .windows) {
        b.installFile("windows_sdl/bin/SDL3.dll", "bin/SDL3.dll");
        b.installFile("windows_sdl/bin/SDL3_ttf.dll", "bin/SDL3_ttf.dll");
    }
    b.installFile("interpreter/starting_memory", "bin/starting_memory");
    b.installFile("interpreter/beep.wav", "bin/beep.wav");
    b.installFile("gui/font/Acme 9 Regular Xtnd.ttf", "bin/font/Acme 9 Regular Xtnd.ttf");
    b.installFile("gui/font/attribution.txt", "bin/font/attribution.txt");

    const assembler_unit_tests = b.addTest(.{ .root_module = assembler_module });

    const run_assembler_unit_tests = b.addRunArtifact(assembler_unit_tests);

    // This exposes a `test` step to the `zig build --help` menu, providing a way
    // for the user to request running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_assembler_unit_tests.step);
}
