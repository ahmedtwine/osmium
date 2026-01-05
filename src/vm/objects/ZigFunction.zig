const std = @import("std");
const Object = @import("../Object.zig");
const builtins = @import("../../modules/builtins.zig");
const Allocator = std.mem.Allocator;

const ZigFunction = @This();

pub const FuncPtr = *const builtins.func_proto;

header: Object = .{ .tag = .zig_function },
func: FuncPtr,

pub fn deinit(zig_func: *const ZigFunction, allocator: Allocator) void {
    _ = zig_func;
    _ = allocator;
}
