// reader.zig
const std = @import("std");
const enums = @import("enums.zig");
const Tag = enums.Tag;
const TagType = enums.TagType;
const types = @import("types.zig");
const NamedTag = types.NamedTag;
const Compound = types.Compound;
const List = types.List;

const Error = error{
    InvalidLength,
} || std.Io.Reader.ReadAllocError;

const Reader = @This();

allocator: std.mem.Allocator,
reader: *std.Io.Reader,
endian: std.builtin.Endian,

pub fn init(allocator: std.mem.Allocator, reader: *std.Io.Reader, endian: std.builtin.Endian) Reader {
    return .{
        .allocator = allocator,
        .reader = reader,
        .endian = endian,
    };
}

pub fn readTag(self: *Reader) Error!Tag {
    var tag_type_buffer: [1]u8 = undefined;
    try self.reader.readSliceEndian(u8, &tag_type_buffer, self.endian);
    const tag_type: TagType = @enumFromInt(tag_type_buffer[0]);

    return try self.readTagPayload(tag_type);
}

pub fn readTagPayload(self: *Reader, tagType: TagType) Error!Tag {
    return switch (tagType) {
        .end => try self.readEndTag(),
        .byte => try self.readByteTag(),
        .short => try self.readShortTag(),
        .int => try self.readIntTag(),
        .long => try self.readLongTag(),
        .float => try self.readFloatTag(),
        .double => try self.readDoubleTag(),
        .byte_array => try self.readByteArrayTag(),
        .string => try self.readStringTag(),
        .list => try self.readListTag(),
        .compound => try self.readCompoundTag(),
        .int_array => try self.readIntArrayTag(),
        .long_array => try self.readLongArrayTag(),
    };
}

fn readEndTag(_: *Reader) !Tag {
    return Tag{ .end = {} };
}

fn readByteTag(self: *Reader) !Tag {
    var value_buf: [1]u8 = undefined;
    try self.reader.readSliceEndian(u8, &value_buf, self.endian);
    return Tag{ .byte = @bitCast(value_buf[0]) };
}

fn readShortTag(self: *Reader) !Tag {
    var value_buf: [1]i16 = undefined;
    try self.reader.readSliceEndian(i16, &value_buf, self.endian);
    return Tag{ .short = value_buf[0] };
}

fn readIntTag(self: *Reader) !Tag {
    var value_buf: [1]i32 = undefined;
    try self.reader.readSliceEndian(i32, &value_buf, self.endian);
    return Tag{ .int = value_buf[0] };
}

fn readLongTag(self: *Reader) !Tag {
    var value_buf: [1]i64 = undefined;
    try self.reader.readSliceEndian(i64, &value_buf, self.endian);
    return Tag{ .long = value_buf[0] };
}

fn readFloatTag(self: *Reader) !Tag {
    var value_buf: [1]u32 = undefined;
    try self.reader.readSliceEndian(u32, &value_buf, self.endian);
    return Tag{ .float = @bitCast(value_buf[0]) };
}

fn readDoubleTag(self: *Reader) !Tag {
    var value_buf: [1]u64 = undefined;
    try self.reader.readSliceEndian(u64, &value_buf, self.endian);
    return Tag{ .double = @bitCast(value_buf[0]) };
}

fn readByteArrayTag(self: *Reader) !Tag {
    var length_buf: [1]i32 = undefined;
    try self.reader.readSliceEndian(i32, &length_buf, self.endian);
    if (length_buf[0] < 0) return error.InvalidLength;

    const arr = try self.reader.readSliceEndianAlloc(self.allocator, i8, @intCast(length_buf[0]), self.endian);
    errdefer self.allocator.free(arr);

    return Tag{ .byte_array = arr };
}

fn readString(self: *Reader) ![]const u8 {
    var length_buf: [1]u16 = undefined;
    try self.reader.readSliceEndian(u16, &length_buf, self.endian);
    const out = try self.reader.readSliceEndianAlloc(self.allocator, u8, length_buf[0], self.endian);
    errdefer self.allocator.free(out);
    return out;
}

fn readStringTag(self: *Reader) !Tag {
    const str = try self.readString();
    return Tag{ .string = str };
}

fn readListTag(self: *Reader) !Tag {
    var element_type_byte_buf: [1]u8 = undefined;
    try self.reader.readSliceEndian(u8, &element_type_byte_buf, self.endian);
    const element_type: TagType = @enumFromInt(element_type_byte_buf[0]);

    var length_buf: [1]i32 = undefined;
    try self.reader.readSliceEndian(i32, &length_buf, self.endian);
    if (length_buf[0] < 0) return error.InvalidLength;

    var list = List.init(self.allocator, element_type);
    errdefer list.deinit();

    var i: usize = 0;
    while (i < @as(usize, @intCast(length_buf[0]))) : (i += 1) {
        const tag = try self.readTagPayload(element_type);
        try list.append(tag);
    }

    return Tag{ .list = list };
}

fn readCompoundTag(self: *Reader) !Tag {
    var compound = Compound.init(self.allocator);
    errdefer compound.deinit();

    while (true) {
        const named_tag = try self.readNamedTag();

        if (named_tag.tag == .end) {
            switch (named_tag.name) {
                .owned => self.allocator.free(named_tag.name.owned),
                .static => {},
            }
            break;
        }

        // Free the name after putting it in the compound
        // The compound should be responsible for managing its own keys
        errdefer switch (named_tag.name) {
            .owned => self.allocator.free(named_tag.name.owned),
            .static => {},
        };

        const key = switch (named_tag.name) {
            .owned => named_tag.name.owned,
            .static => named_tag.name.static,
        };

        // Use putOwned for owned keys so they get freed properly
        switch (named_tag.name) {
            .owned => try compound.putOwned(key, named_tag.tag),
            .static => try compound.put(key, named_tag.tag),
        }
    }

    return Tag{ .compound = compound };
}

pub fn readNamedTag(self: *Reader) !NamedTag {
    var tag_type_buffer: [1]u8 = undefined;
    try self.reader.readSliceEndian(u8, &tag_type_buffer, self.endian);
    const tag_type: TagType = @enumFromInt(tag_type_buffer[0]);

    if (tag_type == .end) {
        return NamedTag{
            .name = .{ .static = "" },
            .tag = Tag{ .end = {} },
        };
    }

    const name = try self.readString();
    errdefer self.allocator.free(name);

    const tag = try self.readTagPayload(tag_type);

    return NamedTag{
        .name = .{ .owned = name },
        .tag = tag,
    };
}

fn readIntArrayTag(self: *Reader) !Tag {
    var length_buf: [1]i32 = undefined;
    try self.reader.readSliceEndian(i32, &length_buf, self.endian);
    if (length_buf[0] < 0) return error.InvalidLength;

    const arr = try self.allocator.alloc(i32, @intCast(length_buf[0]));
    errdefer self.allocator.free(arr);
    return Tag{ .int_array = arr };
}

fn readLongArrayTag(self: *Reader) !Tag {
    var length_buf: [1]i32 = undefined;
    try self.reader.readSliceEndian(i32, &length_buf, .big);
    if (length_buf[0] < 0) return error.InvalidLength;

    const arr = try self.allocator.alloc(i64, @intCast(length_buf[0]));
    errdefer self.allocator.free(arr);

    return Tag{ .long_array = arr };
}
