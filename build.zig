const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
	
	const name = "zon2nix";
	
	// Library
	
	const lib = b.addSharedLibrary(.{
		.name = name,
		.root_source_file = b.path("src/root.zig"),
		.target = target,
		.optimize = optimize,
	});
	b.installArtifact(lib);
	
	// Module
	
	const mod = b.addModule(name, .{
		.root_source_file = b.path("src/root.zig"),
		.target = target,
		.optimize = optimize,
	});
	
	// Executable
	
	const exe = b.addExecutable(.{
		.name = name,
		.root_source_file = b.path("src/main.zig"),
		.target = target,
		.optimize = optimize,
	});
	exe.root_module.addImport(name, mod);
	b.installArtifact(exe);
	
	// Run executable
	
	const run_cmd = b.addRunArtifact(exe);
	run_cmd.step.dependOn(b.getInstallStep());
	
	if (b.args) |args| {
		run_cmd.addArgs(args);
	}
	
	const run_step = b.step("run", "Run the app");
	run_step.dependOn(&run_cmd.step);
	
	// Tests
	
	const unit_tests = b.addTest(.{
		.root_source_file = b.path("src/root.zig"),
		.target = target,
		.optimize = optimize,
	});
	unit_tests.root_module.addImport(name, mod);
	
	const run_unit_tests = b.addRunArtifact(unit_tests);
	const test_step = b.step("test", "Run unit tests");
	test_step.dependOn(&run_unit_tests.step);
}
