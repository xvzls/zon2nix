const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Ast = std.zig.Ast;
const File = std.fs.File;
const Index = std.zig.Ast.Node.Index;
const StringHashMap = std.StringHashMap;
const mem = std.mem;
const string_literal = std.zig.string_literal;

const Dependency = @import("Dependency.zig");
const Meta = @import("Meta.zig");

fn parseAppendDependenciesPrivate(
    alloc: Allocator,
    ast: Ast,
    field_idx: Index,
    deps: *StringHashMap(Dependency),
) !void {
    var deps_buf: [2]Index = undefined;
    const deps_init = ast.fullStructInit(&deps_buf, field_idx) orelse {
        return error.ParseError;
    };
    
    for (deps_init.ast.fields) |dep_idx| {
        var dep: Dependency = .{
            .url = undefined,
            .nix_hash = undefined,
            .done = false,
        };
        var hash: []const u8 = undefined;
        var has_url = false;
        var has_hash = false;

        var dep_buf: [2]Index = undefined;
        const dep_init = ast.fullStructInit(&dep_buf, dep_idx) orelse {
            return error.parseError;
        };

        for (dep_init.ast.fields) |dep_field_idx| {
            const name = try parseFieldName(alloc, ast, dep_field_idx);

            if (mem.eql(u8, name, "url")) {
                dep.url = try parseString(alloc, ast, dep_field_idx);
                has_url = true;
            } else if (mem.eql(u8, name, "hash")) {
                hash = try parseString(alloc, ast, dep_field_idx);
                assert(hash.len != 0);
                has_hash = true;
            }
        }

        if (has_url and has_hash) {
            _ = try deps.getOrPutValue(hash, dep);
        } else {
            return error.parseError;
        }
    }
}

pub fn parse(alloc: Allocator, file: File) !Meta {
    var meta = Meta {
        // .name = "TODO",
        // .version = "TODO",
        .dependencies = StringHashMap(Dependency).init(alloc),
    };
    const content = try alloc.allocSentinel(u8, try file.getEndPos(), 0);
    _ = try file.reader().readAll(content);

    const ast = try Ast.parse(alloc, content, .zon);

    var root_buf: [2]Index = undefined;
    const root_init = ast.fullStructInit(&root_buf, ast.nodes.items(.data)[0].lhs) orelse {
        return error.ParseError;
    };

    for (root_init.ast.fields) |field_idx| {
        if (mem.eql(u8, try parseFieldName(alloc, ast, field_idx), "dependencies")) {
            try parseAppendDependenciesPrivate(alloc, ast, field_idx, &meta.dependencies);
            break;
        }
    }
    
    return meta;
}

pub fn parseAppendDependencies(
    alloc: Allocator,
    dependencies: *StringHashMap(Dependency),
    file: File,
) !void {
    const content = try alloc.allocSentinel(u8, try file.getEndPos(), 0);
    _ = try file.reader().readAll(content);

    const ast = try Ast.parse(alloc, content, .zon);

    var root_buf: [2]Index = undefined;
    const root_init = ast.fullStructInit(&root_buf, ast.nodes.items(.data)[0].lhs) orelse {
        return error.ParseError;
    };

    for (root_init.ast.fields) |field_idx| {
        if (mem.eql(u8, try parseFieldName(alloc, ast, field_idx), "dependencies")) {
            try parseAppendDependenciesPrivate(alloc, ast, field_idx, dependencies);
            break;
        }
    }
}


fn parseFieldName(alloc: Allocator, ast: Ast, idx: Index) ![]const u8 {
    const name = ast.tokenSlice(ast.firstToken(idx) - 2);
    return if (name[0] == '@') string_literal.parseAlloc(alloc, name[1..]) else name;
}

fn parseString(alloc: Allocator, ast: Ast, idx: Index) ![]const u8 {
    return string_literal.parseAlloc(alloc, ast.tokenSlice(ast.nodes.items(.main_token)[idx]));
}

test parse {
    const fs = std.fs;
    const heap = std.heap;
    const testing = std.testing;

    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const basic = try fs.cwd().openFile("fixtures/basic.zon", .{});
    var meta = try parse(alloc, basic);
    basic.close();

    try testing.expectEqual(meta.dependencies.count(), 3);
    try testing.expectEqualStrings(meta.dependencies.get("122048992ca58a78318b6eba4f65c692564be5af3b30fbef50cd4abeda981b2e7fa5").?.url, "https://github.com/ziglibs/known-folders/archive/fa75e1bc672952efa0cf06160bbd942b47f6d59b.tar.gz");
    try testing.expectEqualStrings(meta.dependencies.get("122089a8247a693cad53beb161bde6c30f71376cd4298798d45b32740c3581405864").?.url, "https://github.com/ziglibs/diffz/archive/90353d401c59e2ca5ed0abe5444c29ad3d7489aa.tar.gz");
    try testing.expectEqualStrings(meta.dependencies.get("1220363c7e27b2d3f39de6ff6e90f9537a0634199860fea237a55ddb1e1717f5d6a5").?.url, "https://gist.github.com/antlilja/8372900fcc09e38d7b0b6bbaddad3904/archive/6c3321e0969ff2463f8335da5601986cf2108690.tar.gz");
}
