# Generated by a zon2nix fork
# repo: (https://github.com/xvzls/zon2nix)

{ linkFarm, fetchzip }:
{
  # A sha512 checksum of the contents of
  # build.zig.zon
  checksum = "b1632885af9660bb9e39dd86ad8c020f677adee53279d75fcdc2567878c86fc69675110cea6dbe7772d5484307e6540edbe941d1a48394ccedc8be7093d12c91";
  
  name = "zon2nix";
  version = "0.2.0";
  dependencies = linkFarm "zig-packages" [
  ];
}