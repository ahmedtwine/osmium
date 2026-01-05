const std = @import("std");
const Object = @import("../Object.zig");
const Allocator = std.mem.Allocator;

const Module = @This();

pub const HashMap = std.StringHashMapUnmanaged(*Object);

header: Object = .{ .tag = .module },
name: []const u8,
file: ?[]const u8 = null,
dict: HashMap = .{},

pub fn deinit(module: *const Module, allocator: Allocator) void {
    allocator.free(module.name);
    if (module.file) |f| allocator.free(f);
    var dict = module.dict;
    dict.deinit(allocator);
}

pub fn clone(self: Module, allocator: Allocator) !Module {
    return .{
        .name = try allocator.dupe(u8, self.name),
        .file = if (self.file) |f| try allocator.dupe(u8, f) else null,
        .dict = self.dict,
    };
}
