{
  description = "zon2nix helps you package Zig project with Nix, by converting the dependencies in a build.zig.zon to a Nix expression.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem(system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages.default = pkgs.callPackage ./nix/package.nix {};
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.zig
            pkgs.zls
          ];
        };
      }
    );
}
