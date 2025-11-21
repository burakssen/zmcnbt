const std = @import("std");
const enums = @import("enums.zig");
const Tag = enums.Tag;

pub const TagName = union(enum) {
    owned: []const u8,
    static: []const u8,
};

pub const NamedTag = struct {
    name: TagName,
    tag: Tag,

    pub fn deinit(self: *NamedTag, allocator: std.mem.Allocator) void {
        switch (self.name) {
            .owned => |owned| allocator.free(owned),
            .static => {},
        }
        self.tag.deinit(allocator);
    }
};

pub const Compound = struct {
    allocator: std.mem.Allocator,
    tags: std.StringHashMap(Tag),
    owned_keys: std.StringHashMap(void), // Track which keys are owned

    pub fn init(allocator: std.mem.Allocator) Compound {
        return .{
            .allocator = allocator,
            .tags = std.StringHashMap(Tag).init(allocator),
            .owned_keys = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Compound) void {
        var it = self.tags.iterator();
        while (it.next()) |entry| {
            if (self.owned_keys.contains(entry.key_ptr.*)) {
                self.allocator.free(entry.key_ptr.*);
            }
            entry.value_ptr.deinit(self.allocator);
        }
        self.tags.deinit();
        self.owned_keys.deinit();
    }

    pub fn put(self: *Compound, key: []const u8, value: Tag) !void {
        try self.tags.put(key, value);
    }

    pub fn putOwned(self: *Compound, key: []const u8, value: Tag) !void {
        try self.tags.put(key, value);
        try self.owned_keys.put(key, {});
    }

    pub fn get(self: *const Compound, key: []const u8) ?Tag {
        return self.tags.get(key);
    }
};

pub const List = struct {
    allocator: std.mem.Allocator,
    tag_type: enums.TagType,
    items: std.ArrayList(Tag),

    pub fn init(allocator: std.mem.Allocator, tag_type: enums.TagType) List {
        return .{
            .allocator = allocator,
            .tag_type = tag_type,
            .items = .empty,
        };
    }

    pub fn deinit(self: *List) void {
        for (self.items.items) |*item| {
            item.deinit(self.allocator);
        }
        self.items.deinit(self.allocator);
    }

    pub fn append(self: *List, item: Tag) !void {
        try self.items.append(self.allocator, item);
    }

    pub fn get(self: *const List, index: usize) ?Tag {
        if (index >= self.items.items.len) return null;
        return self.items.items[index];
    }
};
