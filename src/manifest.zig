const root = @import("root");
const std = @import("std");

pub const Manifest = struct {
	allocator: std.mem.Allocator,
	
	name: std.ArrayListUnmanaged(u8),
	version: std.ArrayListUnmanaged(u8),
	dependencies: std.StringHashMapUnmanaged(
		root.Dependency
	),
	
	pub fn init(allocator: std.mem.Allocator) !@This() {
		return .{
			.allocator = allocator,
			
			.name = try std.ArrayListUnmanaged(
				u8
			).initCapacity(allocator, 8),
			.version = try std.ArrayListUnmanaged(
				u8
			).initCapacity(allocator, 8),
			.dependencies = std.StringHashMapUnmanaged(
				root.Dependency
			){},
		};
	}
	
	pub fn deinit(this: *@This()) void {
		const allocator = this.allocator;
		
		this.name.deinit(allocator);
		this.version.deinit(allocator);
		
		var iter = this.dependencies.iterator();
		while (iter.next()) |entry| {
			allocator.free(entry.key_ptr.*);
			entry.value_ptr.deinit(allocator);
		}
		this.dependencies.deinit(allocator);
	}
};

