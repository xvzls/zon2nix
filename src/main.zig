const std = @import("std");

pub const dependency = @import("dependency.zig");
pub const fetch = @import("fetch.zig").fetch;
pub const parse = @import("parse.zig").parse;
pub const codegen = @import("codegen.zig");
pub const utils = @import("utils.zig");
pub const Arguments = @import("arguments.zig").Arguments;

pub const Dependency = dependency.Dependency;

pub fn main() !void {
	var args = std.process.args();
	const program_name = args.next().?;
	
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	defer _ = gpa.deinit();
	
	const allocator = gpa.allocator();
	
	var arguments = Arguments.parse(
		allocator,
		args,
	) catch |err| {
		const stderr = std.io.getStdErr().writer();
		try Arguments.printHelp(program_name, stderr);
		return err;
	};
	defer arguments.deinit();
	
	const default = switch (arguments.commands) {
		.default => |default| default,
		.help => {
			const stdout = std.io.getStdOut().writer();
			try Arguments.printHelp(
				program_name,
				stdout,
			);
			return;
		},
	};
	
	const cwd = std.fs.cwd();
	var file = try cwd.openFile(default.path, .{});
	defer file.close();
	
	const content = try allocator.allocSentinel(
		u8,
		try file.getEndPos(),
		0,
	);
	defer allocator.free(content);
	_ = try file.reader().readAll(content);
	
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
	
	var name: []u8 = undefined;
	defer allocator.free(name);
	var version: []u8 = undefined;
	defer allocator.free(version);
	
	try parse(allocator, &name, &version, &deps, content);
	try fetch(allocator, &deps);
	
	const out = std.io.getStdOut().writer();
	
	const checksum = utils.checksum(
		std.crypto.hash.sha2.Sha512,
		.lower,
		content,
	);
	
	var buffered_out = std.io.bufferedWriter(out);
	try codegen.write(
		allocator,
		&checksum,
		name,
		version,
		&deps,
		buffered_out.writer(),
	);
	try buffered_out.flush();
}

comptime {
	std.testing.refAllDecls(@This());
}

