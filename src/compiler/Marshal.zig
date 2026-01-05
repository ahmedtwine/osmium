//! Serialization of PYC files.

const std = @import("std");
const ObjType = @import("objtype.zig").ObjType;
const CodeObject = @import("CodeObject.zig");
const Object = @import("../vm/Object.zig");
const Vm = @import("../vm/Vm.zig");
const BigIntManaged = std.math.big.int.Managed;

const VmCodeObject = @import("../vm/objects/CodeObject.zig");
const VmString = @import("../vm/objects/String.zig");
const VmInt = @import("../vm/objects/Int.zig");
const VmTuple = @import("../vm/objects/Tuple.zig");

const Marshal = @This();
const readInt = std.mem.readInt;

const Error = error{} || std.mem.Allocator.Error;

const log = std.log.scoped(.marshal);

const PyLong_SHIFT = 15;

const PythonVersion = struct { major: u8, minor: u8 };
const Reference = struct { byte: usize, index: usize };
const FlagRef = struct {
    byte: usize,
    usages: usize = 0,
    content: *const Object,
};

py_version: PythonVersion,

references: std.ArrayListUnmanaged(Reference) = .{},
flag_refs: std.ArrayListUnmanaged(?FlagRef) = .{},

cursor: usize,
bytes: []const u8,
allocator: std.mem.Allocator,

pool: std.ArrayListUnmanaged(*const Object) = .{},

pub fn init(
    allocator: std.mem.Allocator,
    input_bytes: []const u8,
) !Marshal {
    const version = Marshal.getVersion(input_bytes[0..4].*);
    const head_size = switch (version.minor) {
        10 => 16,
        else => unreachable, // not supported
    };

    return .{
        .bytes = try allocator.dupe(u8, input_bytes),
        .cursor = head_size,
        .allocator = allocator,
        .py_version = version,
    };
}

pub fn deinit(marshal: *Marshal) void {
    const allocator = marshal.allocator;

    for (marshal.pool.items) |obj| {
        if (@intFromPtr(obj) <= 0x30) continue;

        std.debug.print("obj: {*}\n", .{obj});
        switch (obj.tag) {
            .tuple => {}, // tuple's objects are stored in the pool elsewhere
            .codeobject => {},
            else => obj.deinit(allocator),
        }
    }

    marshal.pool.deinit(allocator);
    marshal.flag_refs.deinit(allocator);
    marshal.references.deinit(allocator);
    allocator.free(marshal.bytes);
    marshal.* = undefined;
}

/// The return of this function is only valid until the next `createObject` call.
fn createObject(marshal: *Marshal, comptime tag: Object.Tag, data: anytype) !*const Object {
    const object = if (@intFromEnum(tag) < Object.Tag.first_payload) blk: {
        break :blk Object.init(tag);
    } else try Object.create(tag, marshal.allocator, data);
    try marshal.pool.append(marshal.allocator, object);
    return object;
}

pub fn parse(marshal: *Marshal) !*const CodeObject {
    var co_obj = try marshal.readObject();
    const co = co_obj.get(.codeobject);
    return &co.value;
}

fn readSingleString(marshal: *Marshal) ![]const u8 {
    var next_byte = marshal.bytes[marshal.cursor];
    marshal.cursor += 1;

    const allocator = marshal.allocator;

    var ref_id: ?usize = null;
    if (testBit(next_byte, 7)) {
        next_byte = clearBit(next_byte, 7);
        ref_id = marshal.flag_refs.items.len;
        try marshal.flag_refs.append(allocator, null);
    }

    const ty: ObjType = @enumFromInt(next_byte);
    const string: []u8 = switch (ty) {
        .TYPE_SHORT_ASCII_INTERNED,
        .TYPE_SHORT_ASCII,
        => try marshal.readString(.{ .short = true }),
        .TYPE_STRING => try marshal.readString(.{}),
        .TYPE_REF => ref: {
            const index = marshal.readLong(false);
            try marshal.references.append(allocator, .{ .byte = marshal.cursor, .index = index });
            marshal.flag_refs.items[index].?.usages += 1;
            const ref_obj = marshal.flag_refs.items[index].?.content;
            if (ref_obj.tag == .string) {
                const ref_string = ref_obj.get(.string);
                break :ref try allocator.dupe(u8, ref_string.value);
            } else {
                break :ref try allocator.dupe(u8, "<unknown>");
            }
        },
        else => std.debug.panic("TODO: readSingleString {s}", .{@tagName(ty)}),
    };

    if (ref_id) |id| {
        const vm_str = VmString{ .header = .{ .tag = .string }, .value = try allocator.dupe(u8, string) };
        marshal.flag_refs.items[id] = .{
            .byte = marshal.cursor,
            .content = try marshal.createObject(.string, vm_str),
        };
    }

    return string;
}

fn readObject(marshal: *Marshal) Error!*const Object {
    const allocator = marshal.allocator;
    var next_byte = marshal.bytes[marshal.cursor];
    marshal.cursor += 1;

    var ref_id: ?usize = null;
    if (testBit(next_byte, 7)) {
        next_byte = clearBit(next_byte, 7);
        ref_id = marshal.flag_refs.items.len;
        try marshal.flag_refs.append(allocator, null);
    }

    const ty: ObjType = @enumFromInt(next_byte);
    std.debug.print("  readObject: type={s} (0x{x}), cursor={}\n", .{ @tagName(ty), next_byte, marshal.cursor });
    const object: *const Object = switch (ty) {
        .TYPE_NONE => try marshal.createObject(.none, null),
        .TYPE_CODE => code: {
            const code = try marshal.readCodeObject();
            const vm_co = VmCodeObject{ .header = .{ .tag = .codeobject }, .value = code };
            break :code try marshal.createObject(.codeobject, vm_co);
        },

        .TYPE_STRING => string: {
            const string = try marshal.readString(.{});
            const vm_str = VmString{ .header = .{ .tag = .string }, .value = string };
            break :string try marshal.createObject(.string, vm_str);
        },
        .TYPE_SHORT_ASCII_INTERNED,
        .TYPE_SHORT_ASCII,
        => string: {
            const string = try marshal.readString(.{ .short = true });
            const vm_str = VmString{ .header = .{ .tag = .string }, .value = string };
            break :string try marshal.createObject(.string, vm_str);
        },

        .TYPE_INT => int: {
            const new_int = try BigIntManaged.initSet(allocator, marshal.readLong(true));
            const vm_int = VmInt{ .header = .{ .tag = .int }, .value = new_int };
            break :int try marshal.createObject(.int, vm_int);
        },

        // .TYPE_TRUE => try marshal.createObject(.bool_true, null),
        // .TYPE_FALSE => try marshal.createObject(.bool_false, null),

        .TYPE_SMALL_TUPLE => tuple: {
            const size = marshal.readBytes(1)[0];
            const objects = try marshal.allocator.alloc(*const Object, size);
            for (objects) |*object| {
                object.* = try marshal.readObject();
            }
            const vm_tuple = VmTuple{ .header = .{ .tag = .tuple }, .value = objects };
            break :tuple try marshal.createObject(.tuple, vm_tuple);
        },
        .TYPE_REF => ref: {
            const index = marshal.readLong(false);
            try marshal.references.append(allocator, .{ .byte = marshal.cursor, .index = index });
            marshal.flag_refs.items[index].?.usages += 1;
            break :ref marshal.flag_refs.items[index].?.content;
        },
        // .TYPE_BINARY_FLOAT => float: {
        //     const bytes = marshal.readBytes(8);
        //     const float: f64 = @bitCast(bytes[0..8].*);
        //     const float_obj = try marshal.createObject(.float, float);
        //     break :float float_obj;
        // },
        else => {
            std.debug.print("ERROR: Unimplemented type: {s} (0x{x})\n", .{ @tagName(ty), @intFromEnum(ty) });
            std.debug.panic("TODO: marshal.readObject {s}", .{@tagName(ty)});
        },
    };

    if (ref_id) |id| {
        marshal.flag_refs.items[id] = .{
            .byte = marshal.cursor,
            .content = object,
        };
    }

    return object;
}

fn readCodeObject(marshal: *Marshal) Error!CodeObject {
    const allocator = marshal.allocator;

    var result: CodeObject = undefined;
    result.argcount = marshal.readLong(false);
    result.posonlyargcount = marshal.readLong(false);
    result.kwonlyargcount = marshal.readLong(false);
    result.nlocals = marshal.readLong(false);
    result.stacksize = marshal.readLong(false);
    result.flags = marshal.readLong(false);

    const code = try marshal.readSingleString();
    defer marshal.allocator.free(code);

    result.consts = try marshal.readObject();
    std.debug.print("Marshal: consts ptr={*}, tag={s}\n", .{ result.consts, if (@intFromPtr(result.consts) <= 0x30) "SENTINEL" else @tagName(result.consts.tag) });
    result.names = try marshal.readObject();
    std.debug.print("Marshal: names ptr={*}, tag={s}\n", .{ result.names, if (@intFromPtr(result.names) <= 0x30) "SENTINEL" else @tagName(result.names.tag) });
    result.varnames = try marshal.readObject();
    std.debug.print("Marshal: varnames ptr={*}, tag={s}\n", .{ result.varnames, if (@intFromPtr(result.varnames) <= 0x30) "SENTINEL" else @tagName(result.varnames.tag) });
    _ = try marshal.readObject();
    _ = try marshal.readObject();

    result.filename = try marshal.readSingleString();
    result.name = try marshal.readSingleString();
    result.firstlineno = marshal.readLong(false);

    // Python 3.10+ has co_linetable at the end
    _ = try marshal.readObject(); // linetable (bytes object)

    try result.process(code, allocator);

    return result;
}

fn readLong(
    marshal: *Marshal,
    comptime signed: bool,
) if (signed) i32 else u32 {
    const bytes = marshal.readBytes(4);
    return @bitCast(bytes[0..4].*);
}

/// allocates memory to hold the string as the size isn't comptime known
fn readString(
    marshal: *Marshal,
    options: struct { size: ?u32 = null, short: bool = false },
) Error![]u8 {
    const maybe_size = options.size;
    const short = options.short;

    const size: u32 = maybe_size orelse
        if (short) marshal.readBytes(1)[0] else marshal.readLong(false);

    return marshal.allocator.dupe(u8, marshal.readBytes(size));
}

fn readBytes(marshal: *Marshal, n: usize) []const u8 {
    const bytes = marshal.bytes[marshal.cursor..][0..n];
    marshal.cursor += n;
    return bytes;
}

fn getVersion(magic_bytes: [4]u8) PythonVersion {
    const magic_number = readInt(u16, magic_bytes[0..2], .little);

    return switch (magic_number) {
        // We only support 3.10 bytecode
        3430...3439 => .{ .major = 3, .minor = 10 },
        // 3450...3495 => .{ .major = 3, .minor = 11 },
        else => unreachable,
    };
}

fn testBit(int: anytype, comptime offset: u3) bool {
    const mask = @as(u8, 1) << offset;
    return (int & mask) != 0;
}

fn clearBit(int: anytype, comptime offset: u3) @TypeOf(int) {
    return int & ~(@as(u8, 1) << offset);
}
