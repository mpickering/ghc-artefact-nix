let
  np = import <nixpkgs> {};
  ghc = np.callPackage ./artifact.nix {};

in
  ghc
