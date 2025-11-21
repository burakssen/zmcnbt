const std = @import("std");
const enums = @import("enums.zig");
const types = @import("types.zig");

const Tag = enums.Tag;
const TagType = enums.TagType;
const NamedTag = types.NamedTag;
const Compound = types.Compound;
const List = types.List;

pub const ReadError = error{InvalidLength} || std.mem.Allocator.Error || std.Io.Reader.Error;

const Reader = @This();

allocator: std.mem.Allocator,
reader: *std.Io.Reader,
endian: std.builtin.Endian,

pub fn init(allocator: std.mem.Allocator, reader: *std.Io.Reader, endian: std.builtin.Endian) Reader {
    return .{ .allocator = allocator, .reader = reader, .endian = endian };
}

pub fn readTag(self: *Reader) ReadError!Tag {
    const tag_type = try self.readTagType();
    return self.readTagPayload(tag_type);
}

pub fn readNamedTag(self: *Reader) ReadError!NamedTag {
    const tag_type = try self.readTagType();

    if (tag_type == .end) {
        return NamedTag{ .name = .{ .static = "" }, .tag = .{ .end = {} } };
    }

    const name = try self.readString();
    errdefer self.allocator.free(name);

    const tag = try self.readTagPayload(tag_type);
    return NamedTag{ .name = .{ .owned = name }, .tag = tag };
}

pub fn readTagPayload(self: *Reader, tag_type: TagType) ReadError!Tag {
    return switch (tag_type) {
        .end => .{ .end = {} },
        .byte => .{ .byte = try self.readValue(i8) },
        .short => .{ .short = try self.readValue(i16) },
        .int => .{ .int = try self.readValue(i32) },
        .long => .{ .long = try self.readValue(i64) },
        .float => .{ .float = @bitCast(try self.readValue(u32)) },
        .double => .{ .double = @bitCast(try self.readValue(u64)) },
        .byte_array => .{ .byte_array = try self.readArray(i8) },
        .string => .{ .string = try self.readString() },
        .list => .{ .list = try self.readList() },
        .compound => .{ .compound = try self.readCompound() },
        .int_array => .{ .int_array = try self.readArray(i32) },
        .long_array => .{ .long_array = try self.readArray(i64) },
    };
}

// Helper methods
inline fn readTagType(self: *Reader) ReadError!TagType {
    var buf: [1]u8 = undefined;
    try self.reader.readSliceEndian(u8, &buf, self.endian);
    return @enumFromInt(buf[0]);
}

inline fn readValue(self: *Reader, comptime T: type) ReadError!T {
    var buf: [1]T = undefined;
    try self.reader.readSliceEndian(T, &buf, self.endian);
    return buf[0];
}

fn readLength(self: *Reader) ReadError!usize {
    const len = try self.readValue(i32);
    if (len < 0) return error.InvalidLength;
    return @intCast(len);
}

fn readString(self: *Reader) ReadError![]const u8 {
    const len = try self.readValue(u16);
    const str = try self.reader.readSliceEndianAlloc(self.allocator, u8, len, self.endian);
    errdefer self.allocator.free(str);
    return str;
}

fn readArray(self: *Reader, comptime T: type) ReadError![]T {
    const len = try self.readLength();
    return try self.reader.readSliceEndianAlloc(self.allocator, T, len, self.endian);
}

fn readList(self: *Reader) ReadError!List {
    const element_type = try self.readTagType();
    const len = try self.readLength();

    var list = List.init(self.allocator, element_type);
    errdefer list.deinit();

    for (0..len) |_| {
        const tag = try self.readTagPayload(element_type);
        try list.append(tag);
    }

    return list;
}

fn readCompound(self: *Reader) ReadError!Compound {
    var compound = Compound.init(self.allocator);
    errdefer compound.deinit();

    while (true) {
        const named_tag = try self.readNamedTag();

        if (named_tag.tag == .end) {
            if (named_tag.name == .owned) {
                self.allocator.free(named_tag.name.owned);
            }
            break;
        }

        errdefer if (named_tag.name == .owned) {
            self.allocator.free(named_tag.name.owned);
        };

        const key = switch (named_tag.name) {
            .owned => |k| k,
            .static => |k| k,
        };

        switch (named_tag.name) {
            .owned => try compound.putOwned(key, named_tag.tag),
            .static => try compound.put(key, named_tag.tag),
        }
    }

    return compound;
}
