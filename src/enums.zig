// enums.zig
const std = @import("std");
const types = @import("types.zig");
const List = types.List;
const Compound = types.Compound;

pub const TagType = enum(u8) {
    end = 0,
    byte = 1,
    short = 2,
    int = 3,
    long = 4,
    float = 5,
    double = 6,
    byte_array = 7,
    string = 8,
    list = 9,
    compound = 10,
    int_array = 11,
    long_array = 12,
};

pub const Tag = union(TagType) {
    end: void,
    byte: i8,
    short: i16,
    int: i32,
    long: i64,
    float: f32,
    double: f64,
    byte_array: []i8,
    string: []const u8,
    list: List,
    compound: Compound,
    int_array: []i32,
    long_array: []i64,

    pub fn deinit(self: *Tag, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .byte_array => |arr| allocator.free(arr),
            .string => |str| allocator.free(str),
            .list => |*l| l.deinit(),
            .compound => |*c| c.deinit(),
            .int_array => |arr| allocator.free(arr),
            .long_array => |arr| allocator.free(arr),
            else => {},
        }
    }
};
