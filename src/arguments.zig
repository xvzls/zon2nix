const std = @import("std");

pub const ArgumentMap = struct {
	help: bool = false,
	file_path: ?[]u8 = null,
	
	pub fn printHelp(
		program_name: []const u8,
		writer: anytype,
	) !void {
		try writer.print(
			\\Usage: {s} [options] [file-path]
			\\
			\\Options:
			\\  --help     Print help
			\\
			\\Arguments:
			\\  file-path  Path to the ZON (.zon) file
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
		
		var this = @This(){};
		
		while (args_mut.next()) |arg| {
			if (std.mem.startsWith(u8, arg, "--")) {
				const option = arg[2 .. ];
				
				if (std.mem.eql(u8, option, "help")) {
					this.help = true;
					continue;
				}
				
				return error.UnknownOption;
			}
			
			if (this.file_path) |file_path| {
				allocator.free(file_path);
			}
			this.file_path = try allocator.dupe(u8, arg);
		}
		
		return this;
	}
	
	pub fn deinit(
		this: *@This(),
		allocator: std.mem.Allocator,
	) void {
		if (this.file_path) |file_path| {
			allocator.free(file_path);
		}
	}
};

