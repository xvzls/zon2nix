const root = @import("root.zig");
const std = @import("std");

const Ast = std.zig.Ast;

fn parseString(
	allocator: std.mem.Allocator,
	tree: Ast,
	idx: Ast.Node.Index,
) ![]u8 {
	return std.zig.string_literal.parseAlloc(
		allocator,
		tree.tokenSlice(
			tree.nodes.items(.main_token)[idx]
		),
	);
}

fn parseFieldName(
	allocator: std.mem.Allocator,
	tree: Ast,
	idx: Ast.Node.Index,
) ![]u8 {
	const name = tree.tokenSlice(
		tree.firstToken(idx) - 2
	);
	return if (name[0] == '@')
		std.zig.string_literal.parseAlloc(
			allocator,
			name[1 .. ]
		)
	else
		allocator.dupe(u8, name);
}

fn getFieldIndex(
	allocator: std.mem.Allocator,
	tree: Ast,
	init: Ast.full.StructInit,
	name: []const u8,
) !?Ast.Node.Index {
	for (init.ast.fields) |idx| {
		const field_name = try parseFieldName(
			allocator,
			tree,
			idx,
		);
		defer allocator.free(field_name);
		
		if (std.mem.eql(u8, name, field_name)) {
			return idx;
		}
	}
	
	return null;
}

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
	
	pub fn appendDeps(
		this: *@This(),
		content: [:0]const u8,
	) !void {
		const allocator = this.allocator;
		
		var tree = try Ast.parse(
			allocator,
			content,
			.zon,
		);
		defer tree.deinit(allocator);
		
		var buffer: [2]Ast.Node.Index = undefined;
		const root_init = tree.fullStructInit(
			&buffer,
			tree.nodes.items(.data)[0].lhs,
		) orelse return error.ParseError;
		
		const dependencies_idx = try getFieldIndex(
			allocator,
			tree,
			root_init,
			"dependencies",
		) orelse return;
		
		const dependencies_init = tree.fullStructInit(
			&buffer,
			dependencies_idx,
		) orelse return error.ParseError;
		
		for (
			dependencies_init.ast.fields
		) |dependency_idx| {
			const dependency_init = tree.fullStructInit(
				&buffer,
				dependency_idx,
			) orelse return error.ParseError;
			
			const hash = if (try getFieldIndex(
				allocator,
				tree,
				dependency_init,
				"hash",
			)) |idx| try parseString(
				allocator,
				tree,
				idx,
			) else null;
			
			const url = if (try getFieldIndex(
				allocator,
				tree,
				dependency_init,
				"url",
			)) |idx| try parseString(
				allocator,
				tree,
				idx,
			) else null;
			
			if (hash != null and url != null) {
				_ = try this.dependencies.getOrPutValue(
					allocator,
					hash.?,
					.{
						.url = url.?,
						.nix_hash = null,
						.done = false,
					},
				);
			} else return error.ParseError;
		}
	}
	
	test parse {
		var arena = std.heap.ArenaAllocator.init(
			std.testing.allocator
		);
		defer arena.deinit();
		const allocator = arena.allocator();
	
		var file = try std.fs.cwd().openFile(
			"fixtures/basic.zon",
			.{}
		);
		defer file.close();
		
		const content = try allocator.allocSentinel(
			u8,
			try file.getEndPos(),
			0,
		);
		defer allocator.free(content);
		_ = try file.reader().readAll(content);
	
		var manifest = try parse(allocator, content);
	
		try std.testing.expectEqual(
			manifest.dependencies.count(),
			3
		);
	
		for ([_]struct { []const u8, []const u8 }{
			.{
				"122048992ca58a78318b6eba4f65c692564be5af3b30fbef50cd4abeda981b2e7fa5",
				"https://github.com/ziglibs/known-folders/archive/fa75e1bc672952efa0cf06160bbd942b47f6d59b.tar.gz",
			},
			.{
				"122089a8247a693cad53beb161bde6c30f71376cd4298798d45b32740c3581405864",
				"https://github.com/ziglibs/diffz/archive/90353d401c59e2ca5ed0abe5444c29ad3d7489aa.tar.gz",
			},
			.{
				"1220363c7e27b2d3f39de6ff6e90f9537a0634199860fea237a55ddb1e1717f5d6a5",
				"https://gist.github.com/antlilja/8372900fcc09e38d7b0b6bbaddad3904/archive/6c3321e0969ff2463f8335da5601986cf2108690.tar.gz",
			},
		}) |tuple| {
			const hash, const url = tuple;
			try std.testing.expectEqualStrings(
				manifest.dependencies.get(hash).?.url,
				url
			);
		}
	}
	
	pub fn parse(
		allocator: std.mem.Allocator,
		content: [:0]const u8,
	) !@This() {
		var this = try init(allocator);
		errdefer this.deinit();
		
		var tree = try Ast.parse(
			allocator,
			content,
			.zon,
		);
		defer tree.deinit(allocator);
		
		var buffer: [2]Ast.Node.Index = undefined;
		const root_init = tree.fullStructInit(
			&buffer,
			tree.nodes.items(.data)[0].lhs
		) orelse return error.ParseError;
		
		const name = if (try getFieldIndex(
			allocator,
			tree,
			root_init,
			"name",
		)) |idx| try parseString(
			allocator,
			tree,
			idx,
		) else return error.NoNameField;
		defer allocator.free(name);
		try this.name.appendSlice(allocator, name);
		
		const version = if (try getFieldIndex(
			allocator,
			tree,
			root_init,
			"version",
		)) |idx| try parseString(
			allocator,
			tree,
			idx,
		) else return error.NoVersionField;
		defer allocator.free(version);
		try this.version.appendSlice(allocator, version);
		
		try this.appendDeps(content);
		
		return this;
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

