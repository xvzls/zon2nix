const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const mem = std.mem;

const Dependency = @import("Dependency.zig");
const Entry = StringHashMap(Dependency).Entry;

const Meta = @import("Meta.zig");

pub fn write(alloc: Allocator, out: anytype, meta: *const Meta) !void {
    try out.writeAll(
        \\# generated by zon2nix (https://github.com/nix-community/zon2nix)
        \\
        \\{ linkFarm, fetchzip }:
        \\
        \\linkFarm "zig-packages" [
        \\
    );
    var deps = &meta.dependencies;

    const len = deps.count();
    var entries = try alloc.alloc(Entry, len);
    var iter = meta.dependencies.iterator();
    for (0..len) |i| {
        entries[i] = iter.next().?;
    }
    mem.sortUnstable(Entry, entries, {}, lessThan);

    for (entries) |entry| {
        const key = entry.key_ptr.*;
        const dep = entry.value_ptr.*;
        assert(dep.nix_hash.len != 0);
        try out.print(
            \\  {{
            \\    name = "{s}";
            \\    path = fetchzip {{
            \\      url = "{s}";
            \\      hash = "{s}";
            \\    }};
            \\  }}
            \\
        , .{ key, dep.url, dep.nix_hash });
    }

    try out.writeAll("]\n");
}

fn lessThan(_: void, lhs: Entry, rhs: Entry) bool {
    return mem.order(u8, lhs.key_ptr.*, rhs.key_ptr.*) == .lt;
}
