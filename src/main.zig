const std = @import("std");
const zon2nix = @import("zon2nix");

test {
	std.testing.refAllDeclsRecursive(@This());
}

pub const Arguments = @import("arguments.zig").Arguments;

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
	
	var manifest = try zon2nix.parse.parse(allocator, content);
	defer manifest.deinit();
	
	try zon2nix.fetch.fetch(allocator, &manifest);
	
	const out = std.io.getStdOut().writer();
	
	const checksum = zon2nix.utils.checksum(
		std.crypto.hash.sha2.Sha512,
		.lower,
		content,
	);
	
	var buffered_out = std.io.bufferedWriter(out);
	try zon2nix.codegen.write(
		allocator,
		&checksum,
		&manifest,
		buffered_out.writer(),
	);
	try buffered_out.flush();
}

