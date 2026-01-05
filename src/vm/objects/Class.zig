const std = @import("std");
const Object = @import("../Object.zig");
const Allocator = std.mem.Allocator;

const Class = @This();

header: Object = .{ .tag = .class },
name: []const u8,
under_func: *Object,

pub fn deinit(class: *const Class, allocator: Allocator) void {
    allocator.free(class.name);
    class.under_func.deinit(allocator);
}
