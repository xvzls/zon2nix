let
  unstable = import (fetchTarball "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz") { };
in
{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  buildInputs = [
    unstable.zig
    unstable.zls
  ];
}
