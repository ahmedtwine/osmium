const std = @import("std");
const Object = @import("../Object.zig");
const CodeObject = @import("../../compiler/CodeObject.zig");
const Allocator = std.mem.Allocator;

const Function = @This();

header: Object = .{ .tag = .function },
name: []const u8,
co: CodeObject,

pub fn deinit(function: *const Function, allocator: Allocator) void {
    allocator.free(function.name);
    function.co.deinit(allocator);
}
