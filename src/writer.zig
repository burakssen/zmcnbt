const std = @import("std");
const enums = @import("enums.zig");
const types = @import("types.zig");

const Tag = enums.Tag;
const NamedTag = types.NamedTag;

pub const WriteError = error{InvalidLength} || std.mem.Allocator.Error || std.Io.Writer.Error;

const Writer = @This();

allocator: std.mem.Allocator,
writer: *std.Io.Writer,
endian: std.builtin.Endian,

pub fn init(allocator: std.mem.Allocator, writer: *std.Io.Writer, endian: std.builtin.Endian) Writer {
    return .{ .allocator = allocator, .writer = writer, .endian = endian };
}

pub fn writeTag(self: *Writer, tag: Tag) WriteError!void {
    try self.writer.writeByte(@intFromEnum(tag));
    try self.writeTagPayload(tag);
}

pub fn writeNamedTag(self: *Writer, named_tag: NamedTag) WriteError!void {
    try self.writer.writeByte(@intFromEnum(named_tag.tag));

    const name = switch (named_tag.name) {
        .owned => |n| n,
        .static => |n| n,
    };

    try self.writeString(name);
    try self.writeTagPayload(named_tag.tag);
}

pub fn writeTagPayload(self: *Writer, tag: Tag) WriteError!void {
    switch (tag) {
        .end => {},
        .byte => |b| try self.writeValue(i8, b),
        .short => |s| try self.writeValue(i16, s),
        .int => |i| try self.writeValue(i32, i),
        .long => |l| try self.writeValue(i64, l),
        .float => |f| try self.writeValue(u32, @bitCast(f)),
        .double => |d| try self.writeValue(u64, @bitCast(d)),
        .byte_array => |arr| try self.writeArray(i8, arr),
        .string => |str| try self.writeString(str),
        .list => |list| try self.writeList(list),
        .compound => |comp| try self.writeCompound(comp),
        .int_array => |arr| try self.writeArray(i32, arr),
        .long_array => |arr| try self.writeArray(i64, arr),
    }
}

inline fn writeValue(self: *Writer, comptime T: type, value: T) WriteError!void {
    try self.writer.writeInt(T, value, self.endian);
}

fn writeString(self: *Writer, str: []const u8) WriteError!void {
    try self.writeValue(u16, @intCast(str.len));
    try self.writer.writeAll(str);
}

fn writeArray(self: *Writer, comptime T: type, arr: []const T) WriteError!void {
    try self.writeValue(i32, @intCast(arr.len));
    try self.writer.writeSliceEndian(T, arr, self.endian);
}

fn writeList(self: *Writer, list: types.List) WriteError!void {
    try self.writer.writeByte(@intFromEnum(list.tag_type));
    try self.writeValue(i32, @intCast(list.items.items.len));

    for (list.items.items) |item| {
        try self.writeTagPayload(item);
    }
}

fn writeCompound(self: *Writer, compound: types.Compound) WriteError!void {
    var iter = compound.tags.iterator();

    while (iter.next()) |entry| {
        try self.writer.writeByte(@intFromEnum(entry.value_ptr.*));
        try self.writeString(entry.key_ptr.*);
        try self.writeTagPayload(entry.value_ptr.*);
    }

    try self.writer.writeByte(@intFromEnum(Tag{ .end = {} }));
}
