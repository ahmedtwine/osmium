const std = @import("std");
const Object = @import("../Object.zig");
const Allocator = std.mem.Allocator;

const List = @This();

pub const HashMap = std.ArrayListUnmanaged(*Object);

header: Object = .{ .tag = .list },
list: HashMap = .{},

pub fn deinit(self: *const List, allocator: Allocator) void {
    _ = self;
    _ = allocator;
}
