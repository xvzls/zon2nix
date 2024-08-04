const std = @import("std");
const nix = @import("options").nix;

const Dependency = @import("Dependency.zig");
const parse = @import("parse.zig").parse;

const Prefetch = struct {
	hash: []const u8,
	storePath: []const u8,
};

const Worker = struct {
	child: *std.process.Child,
	dep: *Dependency,
};

pub fn fetch(
	allocator: std.mem.Allocator,
	deps: *std.StringHashMap(Dependency),
) !void {
	var workers = try std.ArrayList(Worker).initCapacity(
		allocator,
		deps.count(),
	);
	defer workers.deinit();
	var done = false;
	
	while (!done) {
		var iter = deps.valueIterator();
		while (iter.next()) |dep| {
			if (dep.done) {
				continue;
			}
			
			var child = try allocator.create(
				std.process.Child
			);
			const ref = try std.fmt.allocPrint(
				allocator,
				"tarball+{s}",
				.{ dep.url },
			);
			defer allocator.free(ref);
			
			const argv = &[_][]const u8{
				nix,
				"flake",
				"prefetch",
				"--json",
				"--extra-experimental-features",
				"flakes nix-command",
				ref,
			};
			child.* = std.process.Child.init(
				argv,
				allocator,
			);
			
			child.stdin_behavior = .Ignore;
			child.stdout_behavior = .Pipe;
			
			try child.spawn();
			try workers.append(.{
				.child = child,
				.dep = dep,
			});
		}
		
		const len_before = deps.count();
		done = true;
		
		for (workers.items) |worker| {
			const child = worker.child;
			const dep = worker.dep;
			
			defer allocator.destroy(child);
			
			var reader = std.json.reader(
				allocator,
				child.stdout.?.reader(),
			);
			defer reader.deinit();
			
			var res = try std.json.parseFromTokenSource(
				Prefetch,
				allocator,
				&reader,
				.{ .ignore_unknown_fields = true },
			);
			defer res.deinit();
			
			switch (try child.wait()) {
				.Exited => |code| if (code != 0) {
					std.log.err(
						"{s} exited with code {}",
						.{
							child.argv,
							code,
						},
					);
					return error.NixError;
				},
				.Signal => |signal| {
					std.log.err(
						"{s} terminated with signal {}",
						.{
							child.argv,
							signal,
						},
					);
					return error.NixError;
				},
				.Stopped, .Unknown => {
					std.log.err(
						"{s} finished unsuccessfully",
						.{
							child.argv,
						},
					);
					return error.NixError;
				},
			}
			
			dep.nix_hash = try allocator.dupe(
				u8,
				res.value.hash,
			);
			dep.done = true;
			const path = try std.fs.path.join(
				allocator,
				&[_][]const u8{
					res.value.storePath,
					"build.zig.zon",
				},
			);
			defer allocator.free(path);
			
			const file = std.fs.openFileAbsolute(
				path,
				.{},
			) catch |err| switch (err) {
				error.FileNotFound => continue,
				else => return err,
			};
			defer file.close();
			
			try parse(allocator, deps, file);
			if (deps.count() > len_before) {
				done = false;
			}
		}
		
		workers.clearRetainingCapacity();
	}
}

