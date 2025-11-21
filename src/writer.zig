const std = @import("std");
const enums = @import("enums.zig");
const Tag = enums.Tag;
const types = @import("types.zig");
const NamedTag = types.NamedTag;
const Writer = @This();

const Error = error{
    InvalidLength,
} || std.Io.Writer.Error;

allocator: std.mem.Allocator,
writer: *std.Io.Writer,
endian: std.builtin.Endian,

pub fn init(allocator: std.mem.Allocator, writer: *std.Io.Writer, endian: std.builtin.Endian) Writer {
    return .{
        .allocator = allocator,
        .writer = writer,
        .endian = endian,
    };
}

pub fn writeTag(self: *Writer, tag: Tag) Error!void {
    try self.writer.writeByte(@intFromEnum(tag));
    try self.writeTagPayload(tag);
}

pub fn writeTagPayload(self: *Writer, tag: Tag) Error!void {
    switch (tag) {
        .end => {},
        .byte => |b| try self.writer.writeByte(@bitCast(b)),
        .short => |s| try self.writer.writeInt(i16, s, self.endian),
        .int => |i| try self.writer.writeInt(i32, i, self.endian),
        .long => |l| try self.writer.writeInt(i64, l, self.endian),
        .float => |f| try self.writeFloat(f32, f),
        .double => |d| try self.writeFloat(f64, d),
        .byte_array => |ba| {
            try self.writer.writeInt(i32, @as(i32, @intCast(ba.len)), self.endian);
            try self.writer.writeAll(@ptrCast(ba));
        },
        .string => |str| {
            try self.writer.writeInt(i16, @as(i16, @intCast(str.len)), self.endian);
            try self.writer.writeAll(str);
        },
        .list => |list| {
            try self.writer.writeByte(@intFromEnum(list.tag_type));
            try self.writer.writeInt(i32, @as(i32, @intCast(list.items.items.len)), self.endian);
            for (list.items.items) |item| {
                try self.writeTagPayload(item);
            }
        },
        .compound => |comp| {
            var iter = comp.tags.iterator();
            while (iter.next()) |entry| {
                try self.writer.writeByte(@intFromEnum(entry.value_ptr.*));
                try self.writer.writeInt(i16, @as(i16, @intCast(entry.key_ptr.*.len)), self.endian);
                try self.writer.writeAll(entry.key_ptr.*);
                try self.writeTagPayload(entry.value_ptr.*);
            }
            try self.writer.writeByte(@intFromEnum(Tag{ .end = {} })); // TAG_End
        },
        .int_array => |ia| {
            try self.writer.writeInt(i32, @as(i32, @intCast(ia.len)), self.endian);
            for (ia) |item| {
                try self.writer.writeInt(i32, item, self.endian);
            }
        },
        .long_array => |la| {
            try self.writer.writeInt(i32, @as(i32, @intCast(la.len)), self.endian);
            for (la) |item| {
                try self.writer.writeInt(i64, item, self.endian);
            }
        },
    }
}

pub fn writeNamedTag(self: *Writer, named_tag: NamedTag) Error!void {
    try self.writer.writeByte(@intFromEnum(named_tag.tag));
    try self.writer.writeInt(i16, @as(i16, @intCast(named_tag.name.static.len)), self.endian);
    try self.writer.writeAll(named_tag.name.static);
    try self.writeTagPayload(named_tag.tag);
}

pub fn writeFloat(self: *Writer, comptype: type, value: anytype) Error!void {
    const bytes = @sizeOf(comptype);
    switch (bytes) {
        4 => {
            const as_int: u32 = @bitCast(@as(f32, @bitCast(value)));
            try self.writer.writeInt(u32, as_int, self.endian);
        },
        8 => {
            const as_int: u64 = @bitCast(@as(f64, @bitCast(value)));
            try self.writer.writeInt(u64, as_int, self.endian);
        },
        else => return error.InvalidLength,
    }
}
