const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ChildProcess = std.process.Child;
const StringHashMap = std.StringHashMap;
const fmt = std.fmt;
const fs = std.fs;
const json = std.json;
const log = std.log;

const nix = @import("options").nix;

const Dependency = @import("Dependency.zig");
const parse = @import("parse.zig");

const Prefetch = struct {
    hash: []const u8,
    storePath: []const u8,
};

const Worker = struct {
    child: *ChildProcess,
    dep: *Dependency,
};

pub fn fetch(alloc: Allocator, deps: *StringHashMap(Dependency)) !void {
    var workers = try ArrayList(Worker).initCapacity(alloc, deps.count());
    var done = false;

    while (!done) {
        var iter = deps.valueIterator();
        while (iter.next()) |dep| {
            if (dep.done) {
                continue;
            }

            var child = try alloc.create(ChildProcess);
            const ref = try fmt.allocPrint(alloc, "tarball+{s}", .{dep.url});
            log.debug("running \"nix flake prefetch --json --extra-experimental-features 'flakes nix-command' {s}\"", .{ref});
            const argv = &[_][]const u8{ nix, "flake", "prefetch", "--json", "--extra-experimental-features", "flakes nix-command", ref };
            child.* = ChildProcess.init(argv, alloc);
            child.stdin_behavior = .Ignore;
            child.stdout_behavior = .Pipe;
            try child.spawn();
            try workers.append(.{ .child = child, .dep = dep });
        }

        const len_before = deps.count();
        done = true;

        for (workers.items) |worker| {
            const child = worker.child;
            const dep = worker.dep;

            const buf = try child.stdout.?.readToEndAlloc(alloc, std.math.maxInt(usize));
            defer alloc.free(buf);

            log.debug("nix prefetch for \"{s}\" returned: {s}", .{ dep.url, buf });

            var fbs = std.io.fixedBufferStream(buf);

            var reader = json.reader(alloc, fbs.reader());
            const res = try json.parseFromTokenSourceLeaky(Prefetch, alloc, &reader, .{ .ignore_unknown_fields = true });

            switch (try child.wait()) {
                .Exited => |code| if (code != 0) {
                    log.err("{s} exited with code {}", .{ child.argv, code });
                    return error.NixError;
                },
                .Signal => |signal| {
                    log.err("{s} terminated with signal {}", .{ child.argv, signal });
                    return error.NixError;
                },
                .Stopped, .Unknown => {
                    log.err("{s} finished unsuccessfully", .{child.argv});
                    return error.NixError;
                },
            }

            assert(res.hash.len != 0);
            log.debug("hash for \"{s}\" is {s}", .{ dep.url, res.hash });

            dep.nix_hash = res.hash;
            dep.done = true;

            const path = try fmt.allocPrint(alloc, "{s}" ++ fs.path.sep_str ++ "build.zig.zon", .{res.storePath});
            const file = fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => return err,
            };
            defer file.close();

            try parse.parseAppendDependencies(alloc, deps, file);
            if (deps.count() > len_before) {
                done = false;
            }
        }

        workers.clearRetainingCapacity();
    }
}
