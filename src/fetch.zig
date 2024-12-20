const root = @import("root.zig");
const std = @import("std");

const Prefetch = struct {
	hash: []const u8,
	storePath: []const u8,
};

const Worker = struct {
	child: *std.process.Child,
	dep: *root.Dependency,
};

pub fn fetch(
	allocator: std.mem.Allocator,
	manifest: *root.Manifest,
) !void {
	var workers = try std.ArrayList(Worker).initCapacity(
		allocator,
		manifest.dependencies.count(),
	);
	var done = false;
	
	while (!done) {
		var iter = manifest.dependencies.valueIterator();
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
			
			const argv = &[_][]const u8{
				"nix",
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
		
		const len_before = manifest.dependencies.count();
		done = true;
		
		for (workers.items) |worker| {
			const child = worker.child;
			const dep = worker.dep;
			
			var reader = std.json.reader(
				allocator,
				child.stdout.?.reader(),
			);
			
			const res = try std.json.parseFromTokenSource(
				Prefetch,
				allocator,
				&reader,
				.{ .ignore_unknown_fields = true },
			);
			
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
			
			const file = std.fs.openFileAbsolute(
				path,
				.{},
			) catch |err| switch (err) {
				error.FileNotFound => continue,
				else => return err,
			};
			defer file.close();
			
			const content = try allocator.allocSentinel(
				u8,
				try file.getEndPos(),
				0,
			);
			_ = try file.reader().readAll(content);
			
			try manifest.appendDeps(content);
			if (manifest.dependencies.count() > len_before) {
				done = false;
			}
		}
		
		workers.clearRetainingCapacity();
	}
}

