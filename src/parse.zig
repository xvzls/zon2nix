const root = @import("root");
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

pub fn parse(
	allocator: std.mem.Allocator,
	deps: *std.StringHashMap(root.Dependency),
	file: std.fs.File,
) !void {
	const content = try allocator.allocSentinel(
		u8,
		try file.getEndPos(),
		0,
	);
	_ = try file.reader().readAll(content);
	defer allocator.free(content);
	
	var tree = try Ast.parse(allocator, content, .zon);
	defer tree.deinit(allocator);
	
	var buffer: [2]Ast.Node.Index = undefined;
	const root_init = tree.fullStructInit(
		&buffer,
		tree.nodes.items(.data)[0].lhs
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
	
	for (dependencies_init.ast.fields) |dependency_idx| {
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
			_ = try deps.getOrPutValue(
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
	const fs = std.fs;
	const heap = std.heap;
	const testing = std.testing;

	var arena = heap.ArenaAllocator.init(testing.allocator);
	defer arena.deinit();
	const alloc = arena.allocator();

	var deps = std.StringHashMap(
		root.Dependency
	).init(alloc);
	const basic = try fs.cwd().openFile("fixtures/basic.zon", .{});
	try parse(alloc, &deps, basic);
	basic.close();

	try testing.expectEqual(deps.count(), 3);
	try testing.expectEqualStrings(deps.get("122048992ca58a78318b6eba4f65c692564be5af3b30fbef50cd4abeda981b2e7fa5").?.url, "https://github.com/ziglibs/known-folders/archive/fa75e1bc672952efa0cf06160bbd942b47f6d59b.tar.gz");
	try testing.expectEqualStrings(deps.get("122089a8247a693cad53beb161bde6c30f71376cd4298798d45b32740c3581405864").?.url, "https://github.com/ziglibs/diffz/archive/90353d401c59e2ca5ed0abe5444c29ad3d7489aa.tar.gz");
	try testing.expectEqualStrings(deps.get("1220363c7e27b2d3f39de6ff6e90f9537a0634199860fea237a55ddb1e1717f5d6a5").?.url, "https://gist.github.com/antlilja/8372900fcc09e38d7b0b6bbaddad3904/archive/6c3321e0969ff2463f8335da5601986cf2108690.tar.gz");
}

