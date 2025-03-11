const std = @import("std");
const Dependency = @import("Dependency.zig");

name: []const u8,
version: []const u8,
fingerprint: u64,
dependencies: std.StringHashMap(Dependency),

