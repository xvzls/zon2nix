const std = @import("std");

pub const Arguments = struct {
	allocator: std.mem.Allocator,
	commands: union(enum) {
		default: struct {
			path: []u8,
		},
		help,
	},
	
	pub fn printHelp(
		program_name: []const u8,
		writer: anytype,
	) !void {
		try writer.print(
			\\Usage: {s} [options] [file-path]
			\\
			\\Options:
			\\  --help  Print help
			\\
			\\Parameters:
			\\  path  Path to the ZON (.zon) file
			\\
			,
			.{
				program_name,
			},
		);
	}
	
	pub fn parse(
		allocator: std.mem.Allocator,
		args: std.process.ArgIterator,
	) !@This() {
		var args_mut = args;
		 
		const arg = args_mut.next()
			orelse
		return
			error.NoArguments;
			
		if (std.mem.startsWith(u8, arg, "--help")) {
			return .{
				.allocator = allocator,
				.commands = .help,
			};
		}
		
		return .{
			.allocator = allocator,
			.commands = .{
				.default = .{
					.path = try allocator.dupe(u8, arg),
				},
			},
		};
	}
	
	pub fn deinit(this: *@This()) void {
		const allocator = this.allocator;
		switch (this.commands) {
			.default => |default| {
				allocator.free(default.path);
			},
			.help => {},
		}
	}
};

