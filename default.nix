with import <nixpkgs> { };
let
	unstable = import (fetchTarball "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz") { };
in
pkgs.stdenv.mkDerivation {
	pname = "zon2nix";
	version = "0.1.2";
	
	src = ./.;
	
	dontConfigure = true;
	
	buildInputs = [
		unstable.zls
		unstable.zig
	];
	
	preBuild = ''
		export HOME=$TMPDIR
		export ZIG_GLOBAL_CACHE_DIR="$HOME/.cache/zig"
		mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
	'';
	
	buildPhase = ''
		runHook preBuild
		zig build --prefix $out --release=fast
		runHook postBuild
	'';
	
	installPhase = ''
		runHook preInstall
		zig build --prefix $out --release=fast install
		runHook postInstall
	'';
	
	meta = {
		homepage = "https://codeberg.org/xvzls/zon2nix";
		description = "Convert Zig Zon dependencies to Nix";
		license = pkgs.lib.licenses.mpl20;
		mainProgram = "zon2nix";
	};
}
