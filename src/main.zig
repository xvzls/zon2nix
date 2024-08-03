const std = @import("std");

const Dependency = @import("Dependency.zig");
const fetch = @import("fetch.zig").fetch;
const parse = @import("parse.zig").parse;
const write = @import("codegen.zig").write;

fn getFile(
	dir: std.fs.Dir,
	path: ?[]const u8,
) !std.fs.File {
	if (path) |p| {
		const stat = try dir.statFile(p);
		if (stat.kind != .directory) {
			return dir.openFile(p, .{});
		}
		var sub_dir = try dir.openDir(p, .{});
		defer sub_dir.close();
		return sub_dir.openFile("build.zig.zon", .{});
	} else {
		return dir.openFile("build.zig.zon", .{});
	}
}

pub fn main() !void {
	var args = std.process.args();
	_ = args.skip();
	const dir = std.fs.cwd();
	
	const file = try getFile(dir, args.next());
	defer file.close();
	
	var arena = std.heap.ArenaAllocator.init(
		std.heap.page_allocator,
	);
	defer arena.deinit();
	const allocator = arena.allocator();
	
	var deps = std.StringHashMap(Dependency).init(
		allocator
	);
	defer {
		var iter = deps.iterator();
		while (iter.next()) |entry| {
			allocator.free(entry.key_ptr.*);
			allocator.destroy(entry.value_ptr);
		}
		deps.deinit();
	}
	
	try parse(allocator, &deps, file);
	try fetch(allocator, &deps);
	
	const out = std.io.getStdOut().writer();
	
	var buffered_out = std.io.bufferedWriter(out);
	try write(allocator, deps, buffered_out.writer());
	try buffered_out.flush();
}

comptime {
	std.testing.refAllDecls(@This());
}

