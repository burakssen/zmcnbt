const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zmcnbt_mod = b.addModule("zmcnbt", .{
        .root_source_file = b.path("src/zmcnbt.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zmcnbt_lib = b.addLibrary(.{
        .name = "zmcnbt",
        .root_module = zmcnbt_mod,
    });

    b.installArtifact(zmcnbt_lib);

    const zmcnbt_test = b.addTest(.{
        .name = "zmcnbt_test",
        .root_module = zmcnbt_mod,
    });

    const run_tests = b.addRunArtifact(zmcnbt_test);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
