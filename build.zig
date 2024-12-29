const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;

    const lib = b.addStaticLibrary(.{
        .name = "ini",
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = mode,
    });
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = mode,
    });
    const test_run = b.addRunArtifact(main_tests);
    test_run.has_side_effects = true;

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&test_run.step);
}
