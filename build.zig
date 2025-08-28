const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;
    const disable_llvm = b.option(bool, "disable_llvm", "use the non-llvm zig codegen") orelse false;

    const lib = b.addStaticLibrary(.{
        .name = "ini",
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = mode,
    });
    lib.use_llvm = !disable_llvm;
    lib.use_lld = !disable_llvm;
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/ini.zig"),
        .target = target,
        .optimize = mode,
    });
    main_tests.use_llvm = !disable_llvm;
    main_tests.use_lld = !disable_llvm;

    const test_run = b.addRunArtifact(main_tests);
    test_run.setCwd(b.path("."));
    test_run.has_side_effects = true;

    const test_step = b.step("test", "Run all library tests");
    test_step.dependOn(&test_run.step);
}
