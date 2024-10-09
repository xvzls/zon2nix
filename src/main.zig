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
	
	const arguments = Arguments.parse(args) catch |err| {
		const stderr = std.io.getStdErr().writer();
		try Arguments.printHelp(program_name, stderr);
		return err;
	};
	
	switch (arguments.command) {
		.default => {},
		.help => {
			const stdout = std.io.getStdOut().writer();
			try Arguments.printHelp(
				program_name,
				stdout,
			);
			return;
		},
	}
	
	const file = std.io.getStdIn();
	defer file.close();
	
	var list = try std.ArrayList(u8).initCapacity(
		allocator,
		1 << 10
	);
	defer list.deinit();
	try file.reader().readAllArrayList(&list, 1 << 16);
	
	const content = try list.toOwnedSliceSentinel(0);
	defer allocator.free(content);
	
	var manifest = try zon2nix.Manifest.parse(
		allocator,
		content
	);
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

