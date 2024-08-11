const std = @import("std");

pub const dependency = @import("dependency.zig");
pub const fetch = @import("fetch.zig").fetch;
pub const parse = @import("parse.zig").parse;
pub const write = @import("codegen.zig").write;

pub const Dependency = dependency.Dependency;

fn getFile(
	dir: std.fs.Dir,
	maybe_path: ?[]const u8,
) !std.fs.File {
	const path = maybe_path orelse {
		return dir.openFile("build.zig.zon", .{});
	};
	
	const stat = try dir.statFile(path);
	if (stat.kind != .directory) {
		return dir.openFile(path, .{});
	}
	
	var sub_dir = try dir.openDir(path, .{});
	defer sub_dir.close();
	
	return sub_dir.openFile("build.zig.zon", .{});
}

pub fn main() !void {
	var args = std.process.args();
	_ = args.skip();
	const dir = std.fs.cwd();
	
	const file = try getFile(dir, args.next());
	defer file.close();
	
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	defer _ = gpa.deinit();
	
	const allocator = gpa.allocator();
	
	var deps = std.StringHashMap(Dependency).init(
		allocator
	);
	defer {
		var iter = deps.iterator();
		while (iter.next()) |entry| {
			allocator.free(entry.key_ptr.*);
			entry.value_ptr.deinit(allocator);
		}
		deps.clearAndFree();
		deps.deinit();
	}
	
	try parse(allocator, &deps, file);
	try fetch(allocator, &deps);
	
	const out = std.io.getStdOut().writer();
	
	var buffered_out = std.io.bufferedWriter(out);
	try write(allocator, &deps, buffered_out.writer());
	try buffered_out.flush();
}

comptime {
	std.testing.refAllDecls(@This());
}

