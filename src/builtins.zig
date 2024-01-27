//! Scope References to builtin functions
// NOTE: Builtin functions are expected to append their returns to the stack themselves.

const std = @import("std");
const tracer = @import("tracer");

const Pool = @import("vm/Pool.zig");
const Index = Pool.Index;

const Value = @import("vm/object.zig").Value;

const Vm = @import("vm/Vm.zig");
const fatal = @import("panic.zig").fatal;

pub const BuiltinError = error{OutOfMemory};

pub const func_proto = fn (*Vm, []Index) BuiltinError!void;

/// https://docs.python.org/3.10/library/functions.html
pub const builtin_fns = &.{
    // // zig fmt: off
    .{ "abs", abs },
    .{ "print", print },
    // // zig fmt: on
};

fn abs(vm: *Vm, args: []Index) BuiltinError!void {
    const t = tracer.trace(@src(), "builtin-abs", .{});
    defer t.end();

    if (args.len != 1) fatal("abs() takes exactly one argument ({d} given)", .{args.len});

    const arg_index = args[0];
    const arg = vm.resolveArg(arg_index);

    const index = value: {
        switch (arg.*) {
            .int => |int| {
                var abs_int = int.value;
                abs_int.abs();

                // Create a new Value from this abs
                var abs_val = try Value.Tag.create(.int, vm.allocator, .{ .int = abs_int });
                const abs_index = try abs_val.intern(vm);

                break :value abs_index;
            },
            else => fatal("cannot abs() on type: {s}", .{@tagName(arg.*)}),
        }
    };

    try vm.stack.append(vm.allocator, index);
}

fn print(vm: *Vm, args: []Index) BuiltinError!void {
    const t = tracer.trace(@src(), "builtin-print", .{});
    defer t.end();

    const stdout = std.io.getStdOut().writer();

    for (args) |arg_index| {
        const arg = vm.resolveArg(arg_index);
        printSafe(stdout, "{}", .{arg.fmt(vm.pool)});
    }

    printSafe(stdout, "\n", .{});

    var return_val = Value.Tag.init(.none);
    try vm.stack.append(vm.allocator, try return_val.intern(vm));
}

fn printSafe(writer: anytype, comptime fmt: []const u8, args: anytype) void {
    writer.print(fmt, args) catch |err| {
        fatal("error: {s}", .{@errorName(err)});
    };
}
