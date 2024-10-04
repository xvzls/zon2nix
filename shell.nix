{
	pkgs ? import <nixpkgs> {},
	unstable ? import (fetchTarball "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz") {},
}:
pkgs.mkShell {
	buildInputs = [
		unstable.zls
		unstable.zig
	];
}
