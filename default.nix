{
	pkgs ? import <nixpkgs> {},
	unstable ? import (fetchTarball "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz") {},
	zon ? pkgs.callPackage ./build.zig.zon.nix {},
}:
pkgs.stdenv.mkDerivation {
	pname = zon.name;
	version = zon.version;
	
	src = ./.;
	
	dontConfigure = true;
	
	nativeBuildInputs = [
		unstable.zls
		unstable.zig
	];
	
	patchPhase = ''
		checksum="$(sha512sum build.zig.zon | awk "{print \$1}")"
		if [ "${zon.checksum}" != "$checksum" ]; then
			>&2 echo "
			sha512 checksums don't match for build.zig.zon
			  expected: ${zon.checksum}
			  actual:   $checksum
			"
			exit 1
		fi
		
		export HOME=$TMPDIR
		export ZIG_GLOBAL_CACHE_DIR="$HOME/.cache/zig"
		mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
	'';
	
	buildPhase = ''
		zig build --prefix $out --release=fast
	'';
	
	installPhase = ''
		zig build --prefix $out --release=fast install
	'';
	
	meta = {
		homepage = "https://github.com/xvzls/zon2nix";
		description = "Convert Zig Zon dependencies to Nix";
		license = pkgs.lib.licenses.mpl20;
		mainProgram = zon.name;
	};
}
