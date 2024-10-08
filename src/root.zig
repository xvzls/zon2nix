const std = @import("std");

pub const dependency = @import("dependency.zig");
pub const Dependency = dependency.Dependency;
pub const manifest = @import("manifest.zig");
pub const Manifest = manifest.Manifest;
pub const fetch = @import("fetch.zig");
pub const codegen = @import("codegen.zig");
pub const utils = @import("utils.zig");

test {
	std.testing.refAllDeclsRecursive(@This());
}

