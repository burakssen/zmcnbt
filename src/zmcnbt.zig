const std = @import("std");

pub const types = @import("types.zig");
pub const enums = @import("enums.zig");

pub const Reader = @import("reader.zig");
pub const Writer = @import("writer.zig");

test "Reader reads big-endian NBT data correctly" {
    const allocator = std.testing.allocator;

    var nbt_data: [15]u8 = [_]u8{
        0x0A, 0x00, 0x04, 't', 'e', 's', 't', // TAG_Compound "test"
        0x01, 0x00, 0x03, 'b', 'y', 't', // TAG_Byte "byt"
        0x7F, 0x00, // Value = 127, TAG_End
    };

    var byte_reader: std.Io.Reader = .fixed(&nbt_data);
    var reader = Reader.init(allocator, &byte_reader, .big);

    var named_tag = try reader.readNamedTag();
    defer named_tag.deinit(allocator);

    try std.testing.expectEqualStrings("test", named_tag.name.owned);
    try std.testing.expectEqual(@as(i8, 127), named_tag.tag.compound.get("byt").?.byte);
}

test "Reader reads little-endian NBT data correctly" {
    const allocator = std.testing.allocator;

    var nbt_data: [15]u8 = [_]u8{
        0x0A, 0x04, 0x00, 't', 'e', 's', 't', // TAG_Compound "test"
        0x01, 0x03, 0x00, 'b', 'y', 't', // TAG_Byte "byt"
        0x7F, 0x00, // Value = 127, TAG_End
    };

    var byte_reader: std.Io.Reader = .fixed(&nbt_data);
    var reader = Reader.init(allocator, &byte_reader, .little);

    var named_tag = try reader.readNamedTag();
    defer named_tag.deinit(allocator);

    try std.testing.expectEqualStrings("test", named_tag.name.owned);
    try std.testing.expectEqual(@as(i8, 127), named_tag.tag.compound.get("byt").?.byte);
}

test "Reader handles invalid length error" {
    const allocator = std.testing.allocator;

    var nbt_data: [6]u8 = [_]u8{
        0x09, 0x01, // TAG_List, element type = TAG_Byte
        0xFF, 0xFF, 0xFF, 0xFF, // Length = -1 (invalid)
    };

    var byte_reader: std.Io.Reader = .fixed(&nbt_data);
    var reader = Reader.init(allocator, &byte_reader, .big);

    _ = try byte_reader.discard(.limited(1));
    try std.testing.expectError(error.InvalidLength, reader.readTagPayload(.list));
}

test "Reader handles empty compound tag" {
    const allocator = std.testing.allocator;

    var nbt_data: [4]u8 = [_]u8{
        0x0A, 0x00, 0x00, // TAG_Compound, name length = 0
        0x00, // TAG_End
    };

    var byte_reader: std.Io.Reader = .fixed(&nbt_data);
    var reader = Reader.init(allocator, &byte_reader, .big);

    var named_tag = try reader.readNamedTag();
    defer named_tag.deinit(allocator);

    try std.testing.expectEqualStrings("", named_tag.name.owned);
    try std.testing.expectEqual(@as(usize, 0), named_tag.tag.compound.tags.count());
}

test "Reader handles nested compounds" {
    const allocator = std.testing.allocator;

    var nbt_data: [22]u8 = [_]u8{
        0x0A, 0x00, 0x04, 'r', 'o', 'o', 't', // TAG_Compound "root"
        0x0A, 0x00, 0x03, 'n', 'e', 's', // TAG_Compound "nes"
        0x01, 0x00, 0x03, 'b', 'y', 't', // TAG_Byte "byt"
        0x64, 0x00, 0x00, // Value = 100, TAG_End x2
    };

    var byte_reader: std.Io.Reader = .fixed(&nbt_data);
    var reader = Reader.init(allocator, &byte_reader, .big);

    var named_tag = try reader.readNamedTag();
    defer named_tag.deinit(allocator);

    try std.testing.expectEqualStrings("root", named_tag.name.owned);
    const nested_byte = named_tag.tag.compound.get("nes").?.compound.get("byt").?.byte;
    try std.testing.expectEqual(@as(i8, 100), nested_byte);
}

test "Writer writes big-endian NBT data correctly" {
    const allocator = std.testing.allocator;

    var buffer: [64]u8 = undefined;
    var byte_writer: std.Io.Writer = .fixed(&buffer);
    var writer = Writer.init(allocator, &byte_writer, .big);

    var named_tag = types.NamedTag{
        .name = .{ .static = "test" },
        .tag = enums.Tag{
            .compound = types.Compound.init(allocator),
        },
    };
    defer named_tag.deinit(allocator);

    try named_tag.tag.compound.put("byt", enums.Tag{ .byte = @as(i8, 127) });

    try writer.writeNamedTag(named_tag);

    const expected_data: [15]u8 = [_]u8{
        0x0A, 0x00, 0x04, 't', 'e', 's', 't', // TAG_Compound "test"
        0x01, 0x00, 0x03, 'b', 'y', 't', // TAG_Byte "byt"
        0x7F, 0x00, // Value = 127, TAG_End
    };

    try std.testing.expectEqualSlices(u8, &expected_data, buffer[0..byte_writer.buffered().len]);
}

test "Writer writes little-endian NBT data correctly" {
    const allocator = std.testing.allocator;

    var buffer: [64]u8 = undefined;
    var byte_writer: std.Io.Writer = .fixed(&buffer);
    var writer = Writer.init(allocator, &byte_writer, .little);

    var named_tag = types.NamedTag{
        .name = .{ .static = "test" },
        .tag = enums.Tag{
            .compound = types.Compound.init(allocator),
        },
    };
    defer named_tag.deinit(allocator);

    try named_tag.tag.compound.put("byt", enums.Tag{ .byte = @as(i8, 127) });

    try writer.writeNamedTag(named_tag);

    const expected_data: [15]u8 = [_]u8{
        0x0A, 0x04, 0x00, 't', 'e', 's', 't', // TAG_Compound "test"
        0x01, 0x03, 0x00, 'b', 'y', 't', // TAG_Byte "byt"
        0x7F, 0x00, // Value = 127, TAG_End
    };

    try std.testing.expectEqualSlices(u8, &expected_data, buffer[0..byte_writer.buffered().len]);
}

test "Writer and Reader integration test" {
    const allocator = std.testing.allocator;

    var buffer: [128]u8 = undefined;
    var byte_writer: std.Io.Writer = .fixed(&buffer);
    var writer = Writer.init(allocator, &byte_writer, .big);

    var named_tag = types.NamedTag{
        .name = .{ .static = "root" },
        .tag = enums.Tag{
            .compound = types.Compound.init(allocator),
        },
    };
    defer named_tag.deinit(allocator);

    try named_tag.tag.compound.put("byteTag", enums.Tag{ .byte = @as(i8, 42) });
    try named_tag.tag.compound.put("intTag", enums.Tag{ .int = @as(i32, 123456) });

    try writer.writeNamedTag(named_tag);

    var byte_reader: std.Io.Reader = .fixed(byte_writer.buffered());
    var reader = Reader.init(allocator, &byte_reader, .big);

    var read_named_tag = try reader.readNamedTag();
    defer read_named_tag.deinit(allocator);

    try std.testing.expectEqualStrings("root", read_named_tag.name.owned);
    try std.testing.expectEqual(@as(i8, 42), read_named_tag.tag.compound.get("byteTag").?.byte);
    try std.testing.expectEqual(@as(i32, 123456), read_named_tag.tag.compound.get("intTag").?.int);
}

test "Writer handles empty compound tag" {
    const allocator = std.testing.allocator;

    var buffer: [16]u8 = undefined;
    var byte_writer: std.Io.Writer = .fixed(&buffer);
    var writer = Writer.init(allocator, &byte_writer, .big);

    var named_tag = types.NamedTag{
        .name = .{ .static = "" },
        .tag = enums.Tag{
            .compound = types.Compound.init(allocator),
        },
    };
    defer named_tag.deinit(allocator);

    try writer.writeNamedTag(named_tag);

    const expected_data: [4]u8 = [_]u8{
        0x0A, 0x00, 0x00, // TAG_Compound, name length = 0
        0x00, // TAG_End
    };

    try std.testing.expectEqualSlices(u8, &expected_data, buffer[0..byte_writer.buffered().len]);
}

test "Writer handles nested compounds" {
    const allocator = std.testing.allocator;

    var buffer: [32]u8 = undefined;
    var byte_writer: std.Io.Writer = .fixed(&buffer);
    var writer = Writer.init(allocator, &byte_writer, .big);

    var inner_compound = types.Compound.init(allocator);
    // Remove this line: defer inner_compound.deinit();

    try inner_compound.put("byt", enums.Tag{ .byte = @as(i8, 100) });

    var named_tag = types.NamedTag{
        .name = .{ .static = "root" },
        .tag = enums.Tag{
            .compound = types.Compound.init(allocator),
        },
    };
    defer named_tag.deinit(allocator);

    try named_tag.tag.compound.put("nes", enums.Tag{ .compound = inner_compound });

    try writer.writeNamedTag(named_tag);

    const expected_data: [22]u8 = [_]u8{
        0x0A, 0x00, 0x04, 'r', 'o', 'o', 't', // TAG_Compound "root"
        0x0A, 0x00, 0x03, 'n', 'e', 's', // TAG_Compound "nes"
        0x01, 0x00, 0x03, 'b', 'y', 't', // TAG_Byte "byt"
        0x64, 0x00, 0x00, // Value = 100, TAG_End x2
    };

    try std.testing.expectEqualSlices(u8, &expected_data, buffer[0..byte_writer.buffered().len]);
}
