const std = @import("std");

url: []u8,
nix_hash: ?[]u8,
done: bool,

pub fn deinit(
	this: @This(),
	allocator: std.mem.Allocator
) void {
	allocator.free(this.url);
	if (this.nix_hash) |hash| {
		allocator.free(hash);
	}
}

