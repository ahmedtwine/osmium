const std = @import("std");
const Object = @import("../Object.zig");
const Allocator = std.mem.Allocator;

const Set = @This();

const Context = struct {
    pub fn hash(ctx: Context, obj: *Object) u64 {
        _ = ctx;
        return @intFromPtr(obj);
    }

    pub fn eql(ctx: Context, a: *Object, b: *Object) bool {
        _ = ctx;
        return a == b;
    }
};

pub const HashMap = std.HashMapUnmanaged(*Object, void, Context, 80);

header: Object = .{ .tag = .set },
set: HashMap = .{},
frozen: bool = false,

pub fn deinit(self: *const Set, allocator: Allocator) void {
    _ = self;
    _ = allocator;
}
