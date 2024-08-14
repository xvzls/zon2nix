const std = @import("std");

pub const dependency = @import("dependency.zig");
pub const fetch = @import("fetch.zig").fetch;
pub const parse = @import("parse.zig").parse;
pub const write = @import("codegen.zig").write;
pub const arguments = @import("arguments.zig");

pub const Dependency = dependency.Dependency;

pub fn readAllocSentinel(
	file: std.fs.File,
	allocator: std.mem.Allocator,
) ![:0]u8 {
	const content = try allocator.allocSentinel(
		u8,
		try file.getEndPos(),
		0,
	);
	_ = try file.reader().readAll(content);
	return content;
}

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
	
	return getFile(sub_dir, null);
}

fn getContent(
	maybe_path: ?[]const u8,
	allocator: std.mem.Allocator,
) ![:0]u8 {
	const dir = std.fs.cwd();
	
	const file = try getFile(dir, maybe_path);
	defer file.close();
	
	return readAllocSentinel(file, allocator);
}

pub fn main() !void {
	var args = std.process.args();
	const program_name = args.next().?;
	
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	defer _ = gpa.deinit();
	
	const allocator = gpa.allocator();
	
	var arg_map = arguments.ArgumentMap.parse(
		allocator,
		args,
	) catch |err| {
		const stderr = std.io.getStdErr().writer();
		try arguments.ArgumentMap.printHelp(
			program_name,
			stderr,
		);
		return err;
	};
	defer arg_map.deinit(allocator);
	
	if (arg_map.help) {
		const stdout = std.io.getStdOut().writer();
		try arguments.ArgumentMap.printHelp(
			program_name,
			stdout,
		);
		return;
	}
	
	const content = try getContent(
		arg_map.file_path,
		allocator,
	);
	defer allocator.free(content);
	
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
	
	try parse(allocator, &deps, content);
	try fetch(allocator, &deps);
	
	const out = std.io.getStdOut().writer();
	
	var buffered_out = std.io.bufferedWriter(out);
	try write(allocator, &deps, buffered_out.writer());
	try buffered_out.flush();
}

comptime {
	std.testing.refAllDecls(@This());
}

