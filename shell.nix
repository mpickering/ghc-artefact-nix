let
  np = import <nixpkgs> {};
  ghc = np.callPackage ./artifact.nix {} {};
in np.mkShell { buildInputs = [ghc np.haskellPackages.cabal-install ]; }
