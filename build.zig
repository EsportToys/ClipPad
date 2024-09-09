const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "ClipPad",
        .root_source_file = b.path("src/main.zig"),
        .win32_manifest = b.path("res/main.manifest"),
        .target = b.standardTargetOptions(.{}),
        .optimize = .ReleaseSmall,
    });
    exe.subsystem = .Windows;
    exe.addWin32ResourceFile(.{
        .file = b.path("res/main.rc"),
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
