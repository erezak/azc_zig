const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define the executable named "azc"
    const exe = b.addExecutable(.{
        .name = "azc",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the executable as the default build step
    b.installArtifact(exe);

    // Make the executable the default step for `zig build`
    b.default_step.dependOn(&exe.step);

    // Define and run tests
    const run_tests = b.addTest(.{
        .name = "tests",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Make `zig build test` run the test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
