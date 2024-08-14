const std = @import("std");

pub const ArgumentMap = struct {
	file_path: ?[]const u8 = null,
	
	pub fn parse(
		args: std.process.ArgIterator,
	) !@This() {
		var args_mut = args;
		
		var this = @This(){};
		
		this.file_path = args_mut.next();
		
		return this;
	}
	
	pub fn deinit(this: *@This()) void {
		_ = this;
	}
};

