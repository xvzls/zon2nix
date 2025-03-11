{
	pkgs ? import <nixpkgs> { },
	unstable ? import <unstable> {},
}:
pkgs.mkShell {
	nativeBuildInputs = [
		unstable.zig
		unstable.zls
	];
}
