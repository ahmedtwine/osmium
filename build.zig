// Copyright (c) 2024, David Rubin <daviru007@icloud.com>
//
// SPDX-License-Identifier: GPL-3.0-only

// Import the standard library and builtin modules
const std = @import("std");
const builtin = @import("builtin");

// Import a custom module for test cases
const cases = @import("tests/cases.zig");

// The main build function, which takes a pointer to a Build struct
pub fn build(b: *std.Build) !void {
    // Set up standard build options
    const optimize = b.standardOptimizeOption(.{}); // Get optimization level from command line or use default
    const target = b.standardTargetOptions(.{}); // Get target from command line or use default

    // Create an executable build artifact
    const exe = b.addExecutable(.{
        .name = "osmium", // Name of the executable
        .root_source_file = b.path("src/main.zig"), // Path to the main source file
        .target = target, // Set the target
        .optimize = optimize, // Set the optimization level
    });

    // Set up installation of the executable
    const exe_install = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .{ .custom = "." } }, // Install to the current directory
    });
    b.getInstallStep().dependOn(&exe_install.step); // Make sure the install step depends on this artifact

    // Set up build options
    const trace = b.option(
        bool,
        "trace",
        "Enables tracing of the compiler using the default backend (spall)",
    ) orelse false; // Default to false if not specified

    // Determine which tracing backend to use
    const backend: TraceBackend = bend: {
        if (trace) {
            break :bend b.option(
                TraceBackend,
                "trace-backend",
                "Switch between what backend to use. None is default.",
            ) orelse .None;
        }
        break :bend .None;
    };

    // Option to use LLVM
    const use_llvm = b.option(bool, "use-llvm", "Uses llvm to compile Osmium. Default true.") orelse true;
    exe.use_llvm = use_llvm;
    exe.use_lld = use_llvm;

    // Various debug and logging options
    const enable_logging = b.option(bool, "log", "Enable debug logging.") orelse false;
    const enable_debug_extensions = b.option(
        bool,
        "debug-extensions",
        "Enable commands and options useful for debugging the compiler",
    ) orelse (optimize == .Debug);
    const enable_debug = b.option(bool, "debug", "Builds a VM debugger into the program") orelse false;

    // Add build options to the executable
    const exe_options = b.addOptions();
    exe_options.addOption(bool, "trace", trace);
    exe_options.addOption(TraceBackend, "backend", backend);
    exe_options.addOption(bool, "enable_logging", enable_logging);
    exe_options.addOption(usize, "src_file_trimlen", std.fs.path.dirname(std.fs.path.dirname(@src().file).?).?.len);
    exe_options.addOption(bool, "enable_debug_extensions", enable_debug_extensions);
    exe_options.addOption(bool, "build_debug", enable_debug);
    exe.root_module.addOptions("options", exe_options);
    exe_options.addOption([]const u8, "lib_path", b.fmt("{s}/python/Lib", .{b.install_path}));

    // Add ARM-specific files if the target is ARM64
    if (target.result.cpu.arch == .aarch64) {
        exe.addCSourceFile(.{
            .file = b.path("src/arm_support.c"),
            .flags = &[_][]const u8{"-march=armv8-a"},
        });
        exe.addAssemblyFile(b.path("src/arm_asm_support.s"));
    }

    // Set up dependencies
    const tracer_dep = b.dependency("tracer", .{
        .optimize = optimize,
        .target = target,
    });
    const libgc_dep = b.dependency("libgc", .{
        .optimize = optimize,
        .target = target,
    });
    const cpython_dep = b.dependency("cpython", .{
        .optimize = optimize,
        .target = target,
    });

    // Add imports to the executable
    exe.root_module.addImport("tracer", tracer_dep.module("tracer"));
    exe.root_module.addImport("gc", libgc_dep.module("gc"));
    exe.root_module.addImport("cpython", cpython_dep.module("cpython"));

    // Conditionally add debug-related dependency
    if (enable_debug) {
        if (b.lazyDependency("libvaxis", .{
            .optimize = optimize,
            .target = target,
        })) |libvaxis| {
            exe.root_module.addImport("vaxis", libvaxis.module("vaxis"));
        }
    }

    // Set up Python library installation
    const libpython_install = b.addInstallDirectory(.{
        .source_dir = cpython_dep.builder.dependency("python", .{}).path("Lib"),
        .install_dir = .{ .custom = "python" },
        .install_subdir = "Lib",
    });
    exe.step.dependOn(&libpython_install.step);

    // Set up run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Add any command-line arguments
    if (b.args) |args| run_cmd.addArgs(args);

    // Create a "run" step
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Create an "opcode" step for generating opcodes
    const opcode_step = b.step("opcode", "Generate opcodes");
    generateOpCode(b, opcode_step);

    // Set up test step
    const test_step = b.step("test", "Test Osmium");
    try cases.addCases(b, target, test_step, exe, cpython_dep.artifact("cpython"));
    test_step.dependOn(&libpython_install.step);
}

// Enum for different tracing backends
const TraceBackend = enum {
    Spall,
    Chrome,
    None,
};

// Function to generate opcodes
fn generateOpCode(
    b: *std.Build,
    step: *std.Build.Step,
) void {
    // Create an executable for opcode generation
    const translator = b.addExecutable(.{
        .name = "opcode2zig",
        .root_source_file = b.path("tools/opcode2zig.zig"),
        .target = b.host,
        .optimize = .ReleaseFast,
    });

    // Set up a run command for the opcode generator
    const run_cmd = b.addRunArtifact(translator);

    // Add arguments to the run command
    run_cmd.addArg("vendor/opcode.h");
    run_cmd.addArg("src/compiler/opcodes.zig");

    // Make the opcode step depend on this run command
    step.dependOn(&run_cmd.step);
}
