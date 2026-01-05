const std = @import("std");
const Object = @import("../Object.zig");
const CodeObject = @import("../../compiler/CodeObject.zig");
const Allocator = std.mem.Allocator;

const Function = @This();

header: Object = .{ .tag = .function },
name: []const u8,
co: CodeObject,

pub fn deinit(function: *const Function, allocator: Allocator) void {
    _ = function;
    _ = allocator;
    // Note: name and co are owned by the marshal pool, not by this function.
    // They will be freed when marshal.deinit() runs.
}
