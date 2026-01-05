//! A 3.10 CodeObject

const std = @import("std");
const Marshal = @import("Marshal.zig");
const Instruction = @import("Instruction.zig");
const OpCode = @import("opcodes.zig").OpCode;
const Object = @import("../vm/Object.zig");
const Reference = Marshal.Reference;
const FlagRef = Marshal.FlagRef;

const CodeObject = @This();

name: []const u8,
filename: []const u8,

consts: *const Object,
names: *const Object,
varnames: *const Object,

/// https://github.com/python/cpython/blob/3.10/Objects/lnotab_notes.txt
// lnotab_obj: Object,
// lnotab: std.AutoHashMapUnmanaged(u32, u32) = .{},

argcount: u32,
posonlyargcount: u32,
kwonlyargcount: u32,
stacksize: u32,
nlocals: u32,
firstlineno: u32,
flags: u32,

instructions: []const Instruction,

index: usize = 0,

/// Assumes the same allocator was used to allocate every field
pub fn deinit(co: *const CodeObject, allocator: std.mem.Allocator) void {
    allocator.free(co.name);
    allocator.free(co.filename);

    co.consts.deinit(allocator);
    co.names.deinit(allocator);
    co.varnames.deinit(allocator);
    // co.freevars.deinit(allocator);
    // co.cellvars.deinit(allocator);

    allocator.free(co.instructions);

    // co.lnotab.deinit(allocator);
    // co.lnotab_obj.deinit(allocator);
}

pub fn format(
    self: CodeObject,
    comptime fmt: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    std.debug.assert(fmt.len == 0);

    // print out the metadata about the CodeObject
    try writer.print("Name:\t\t{s}\n", .{self.name});
    try writer.print("Filename:\t{s}\n", .{self.filename});
    try writer.print("Argument count:\t{d}\n", .{self.argcount});
    try writer.print("Stack size:\t{d}\n", .{self.stacksize});

    // const consts_tuple = self.consts.get(.tuple);
    // if (consts_tuple.len != 0) {
    //     try writer.writeAll("Constants:\n");
    //     for (consts_tuple, 0..) |con, i| {
    //         try writer.print("\t{d}: {}\n", .{ i, con });
    //     }
    // }

    // const names_tuple = self.names.get(.tuple);
    // if (names_tuple.len != 0) {
    //     try writer.writeAll("Names:\n");
    //     for (names_tuple, 0..) |name, i| {
    //         try writer.print("\t{d}: {}\n", .{ i, name });
    //     }
    // }

    // if (self.varnames.len != 0) {
    //     try writer.writeAll("Variables:\n");
    //     for (self.varnames, 0..) |varname, i| {
    //         try writer.print("\t{d}: {}\n", .{ i, varname });
    //     }
    // }
}

pub fn process(
    co: *CodeObject,
    bytes: []const u8,
    allocator: std.mem.Allocator,
) !void {
    const num_instructions = bytes.len / 2;
    const instructions = try allocator.alloc(Instruction, num_instructions);

    var cursor: usize = 0;
    for (0..num_instructions) |i| {
        const byte = bytes[cursor];
        instructions[i] = .{
            .op = @enumFromInt(byte),
            .extra = if (byte >= 90) bytes[cursor + 1] else 0,
        };
        cursor += 2;
    }

    co.instructions = instructions;
    co.index = 0;
    // try co.unpackLnotab(allocator);
}

// pub fn unpackLnotab(
//     co: *CodeObject,
//     allocator: std.mem.Allocator,
// ) !void {
//     const lnotab = co.lnotab_obj;
//     const array = lnotab.get(.string);

//     var lineno: u32 = 0;
//     var addr: u32 = 0;

//     var iter = std.mem.window(u8, array, 2, 2);
//     while (iter.next()) |entry| {
//         const addr_incr, var line_incr = entry[0..2].*;
//         addr += addr_incr;
//         if (line_incr >= 0x80) {
//             line_incr -%= 255;
//         }
//         lineno += line_incr;

//         try co.lnotab.put(allocator, addr, lineno);
//     }
// }

// Helper functions

pub fn getConst(co: *const CodeObject, index: usize) *const Object {
    const consts = co.consts.get(.tuple).value;
    return consts[index];
}

pub fn getName(co: *const CodeObject, index: usize) []const u8 {
    std.debug.print("    getName: co.names ptr = {*}\n", .{co.names});
    if (@intFromPtr(co.names) <= 0x30) {
        std.debug.panic("getName: co.names is a sentinel (None/bool), cannot get name index {}", .{index});
    }
    std.debug.print("    getName: co.names.tag = {s}\n", .{@tagName(co.names.tag)});
    const names = co.names.get(.tuple).value;
    std.debug.print("    getName: names.len = {}\n", .{names.len});
    return names[index].get(.string).value;
}

pub fn addr2Line(co: *const CodeObject, addr: u32) u32 {
    _ = addr;
    return co.firstlineno;
}

const Sha256 = std.crypto.hash.sha2.Sha256;

/// Returns a hash unique to the data stored in the CodeObject
pub fn hash(
    co: *const CodeObject,
) u256 {
    var hasher = Sha256.init(.{});

    hasher.update(co.filename);
    hasher.update(co.name);

    hasher.update(std.mem.asBytes(&co.argcount));
    hasher.update(std.mem.asBytes(&co.stacksize));
    hasher.update(std.mem.asBytes(&co.consts));
    hasher.update(std.mem.asBytes(&co.names));
    hasher.update(std.mem.asBytes(&co.varnames));

    for (co.instructions) |inst| {
        hasher.update(std.mem.asBytes(&inst));
    }

    var out: [Sha256.digest_length]u8 = undefined;
    hasher.final(&out);

    return @bitCast(out);
}
