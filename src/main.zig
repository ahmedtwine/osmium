const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("options");

const Graph = @import("analysis/Graph.zig");
const RefMask = @import("analysis/RefMask.zig");

const Python = @import("frontend/Python.zig");
const Marshal = @import("compiler/Marshal.zig");
const crash_report = @import("crash_report.zig");
const Vm = @import("vm/Vm.zig");
const debug = if (build_options.build_debug) @import("vm/debug.zig") else {};

const main_log = std.log.scoped(.main);

const version = "0.1.0";

pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe, .ReleaseFast => .info,
        .ReleaseSmall => .err,
    },
    .logFn = log,
    .enable_segfault_handler = false, // we have our own!
};

pub const panic = crash_report.panic;

var log_scopes: std.ArrayListUnmanaged([]const u8) = .{};

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(level) > @intFromEnum(std.options.log_level) or
        @intFromEnum(level) > @intFromEnum(std.log.Level.info))
    {
        if (!build_options.enable_logging) return;

        const scope_name = @tagName(scope);
        for (log_scopes.items) |log_scope| {
            if (std.mem.eql(u8, log_scope, scope_name))
                break;
        } else return;
    }

    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    // Print the message to stderr, silently ignoring any errors
    std.debug.print(prefix1 ++ prefix2 ++ format ++ "\n", args);
}

const Args = struct {
    make_graph: bool,
    run_debug: bool,
    run: bool,
};

pub fn main() !u8 {
    // crash_report.initialize();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};
    const allocator = blk: {
        if (builtin.mode == .Debug) break :blk gpa.allocator();
        if (builtin.link_libc) break :blk std.heap.c_allocator;
        @panic("osmium doesn't support non-libc compilations yet");
    };
    defer {
        log_scopes.deinit(allocator);
        _ = gpa.deinit();
    }

    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();

    var file_path: ?[:0]const u8 = null;
    var options: Args = .{
        .make_graph = false,
        .run_debug = false,
        .run = true,
    };

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            usage();
            return 0;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            versionPrint();
            return 0;
        } else if (std.mem.endsWith(u8, arg, ".py")) {
            if (file_path) |earlier_path| {
                fatal("two .py files passed, first was: {s}", .{earlier_path});
            }
            file_path = arg;
        } else if (std.mem.eql(u8, arg, "--debug-log")) {
            if (!build_options.enable_logging) {
                main_log.warn("Osmium compiled without -Dlog, --debug-log has no effect", .{});
            } else {
                const scope = args.next() orelse fatal("--debug-log expects scope", .{});
                try log_scopes.append(allocator, scope);
            }
        } else if (std.mem.eql(u8, arg, "--graph")) {
            options.make_graph = true;
        } else if (std.mem.eql(u8, arg, "--no-run")) {
            options.run = false;
        } else if (std.mem.eql(u8, arg, "--debug")) {
            options.run_debug = true;
            options.run = false;
        }
    }

    if (file_path) |path| {
        try runFile(allocator, path, options);
        return 0;
    }

    usage();
    fatal("expected a file!", .{});
}

fn usage() void {
    const usage_string =
        \\
        \\Usage:
        \\ osmium <file>.py/pyc [options]
        \\
        \\ Options:
        \\  --help, -h    Print this message
        \\  --version, -v Print the version
        \\
        \\ Debug Options:
        \\  --no-run      Doesn't run the VM, useful for debugging Osmium
        \\  --graph,      Creates a "graph.bin" which contains CFG information
        \\  --debug,      Runs a interactable debug mode to debug the VM
        \\
    ;

    var buf: [4096]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buf);
    stdout.interface.print(usage_string, .{}) catch |err| {
        fatal("Failed to print usage: {}\n", .{err});
    };
    stdout.interface.flush() catch {};
}

fn versionPrint() void {
    var buf: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buf);

    stdout.interface.print("Osmium {s}\n", .{version}) catch |err| {
        fatal("Failed to print version: {s}\n", .{@errorName(err)});
    };
    stdout.interface.flush() catch {};
}

fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt, args);
    std.posix.exit(1);
}

pub fn runFile(
    base_allocator: std.mem.Allocator,
    file_name: [:0]const u8,
    options: Args,
) !void {

    // Trying Arena Allocator for now
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const source_file = try std.fs.cwd().openFile(file_name, .{ .lock = .exclusive });
    defer source_file.close();

    const source_file_size = (try source_file.stat()).size;
    const source = try source_file.readToEndAllocOptions(
        allocator,
        source_file_size,
        null,
        .@"1",
        0,
    );
    defer allocator.free(source);

    std.debug.print("\n=== Python Source Code ===\n", .{});
    std.debug.print("File: {s}\n", .{file_name});
    std.debug.print("Size: {d} bytes\n\n", .{source.len});
    std.debug.print("{s}\n", .{source});

    const pyc = try Python.parse(source, file_name, allocator);
    defer allocator.free(pyc);

    std.debug.print("\n=== Python Bytecode (PYC) ===\n", .{});
    std.debug.print("Length: {d} bytes\n", .{pyc.len});
    std.debug.print("Hex dump:\n", .{});
    for (pyc, 0..) |byte, i| {
        if (i % 16 == 0) std.debug.print("\n{x:0>4}: ", .{i});
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n\n", .{});

    var marshal = try Marshal.init(allocator, pyc);
    defer marshal.deinit();

    const code = try marshal.parse();
    std.debug.print("\n=== Parsed Code Object ===\n", .{});
    std.debug.print("Name: {s}\n", .{code.name});
    std.debug.print("Filename: {s}\n", .{code.filename});
    std.debug.print("Argcount: {}\n", .{code.argcount});
    std.debug.print("Nlocals: {}\n", .{code.nlocals});
    std.debug.print("Stacksize: {}\n", .{code.stacksize});
    std.debug.print("Instructions: {}\n", .{code.instructions.len});
    std.debug.print("\nBytecode Instructions:\n", .{});
    for (code.instructions, 0..) |inst, i| {
        std.debug.print("  [{:0>3}] {s:<20} extra={}\n", .{ i, @tagName(inst.op), inst.extra });
    }
    std.debug.print("\n", .{});

    if (options.run) {
        std.debug.print("=== Running VM ===\n", .{});

        var vm = try Vm.init(allocator, code.*);
        defer vm.deinit();

        try vm.initBuiltinMods(file_name);
        try vm.run();

        std.debug.print("\n=== VM Execution Complete ===\n", .{});
    }
}
