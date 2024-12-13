const std = @import("std");

pub const Commands = enum {
	default,
	help,
};

command: Commands,

pub fn printHelp(
	program_name: []const u8,
	writer: anytype,
) !void {
	try writer.print(
		\\Usage: {s} [subcommand]
		\\
		\\Input:
		\\  <stdin>  Zon file contents
		\\
		\\Subcommands:
		\\  help  Print help
		\\
		\\Examples:
		\\  Convert `build.zig.zon` to a nix file
		\\  $ zon2nix < build.zig.zon > build.zig.zon.nix
		\\
		,
		.{
			program_name,
		},
	);
}

pub fn parse(
	args: std.process.ArgIterator,
) !@This() {
	var args_mut = args;
	 
	const arg = args_mut.next() orelse return .{
		.command = .default,
	};
	
	for (std.enums.values(Commands)) |command| {
		if (std.mem.eql(
			u8,
			arg,
			// std.enums.tagName(Commands, command)
			@tagName(command)
		)) {
			return .{
				.command = command,
			};
		}
	}
	
	return error.InvalidCommand;
}

