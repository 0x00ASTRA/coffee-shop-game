const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .target = target,
        .optimize = optimize,
        .name = "Coffee_Shop_Game",
        .root_source_file = b.path("src/main.zig"),
    });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "run the game");
    run_step.dependOn(&run_exe.step);

    const main_test = b.addTest(.{
        .name = "MainTest",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    const run_main_test = b.addRunArtifact(main_test);
    const main_test_step = b.step("test", "run the main tests.");
    main_test_step.dependOn(&run_main_test.step);
}
