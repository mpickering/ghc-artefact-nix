{ branch ? "master", fork ? "ghc" }:
let
  np = import <nixpkgs> {};
  ghc = self: ref: self.callPackage ./artifact.nix {} ref;
  ol = self: super:
    {
      ghcHEAD = ghc self {
        bindistTarball = self.callPackage ./gitlab-artifact.nix {} { inherit fork branch; };
      };
    };
in
  import <nixpkgs> { overlays = [ol]; }
