{ baseNixpkgs ? (import <nixpkgs> {}) }:

let
  nixpkgsSrc = baseNixpkgs.fetchFromGitHub {
    owner = "nixos";
    repo = "nixpkgs";
    rev = "c2ef0cee28a17f6fcb64ea0d0fb705f8c5ee6cf3";
    sha256 = "05vvj1693p6d56l9wl7f2cxdrn57sdgx6wa1vph67brl8xzlmzbc";
  };
  nixpkgs = import nixpkgsSrc {};
in with nixpkgs;

let
  fromBindist = { url, sha256, ncursesVersion ? "6" }:
    nixpkgs.callPackage ./artifact.nix {} {
      bindistTarball = nixpkgs.fetchurl {
        inherit url sha256;
      };
      inherit ncursesVersion;
    };
  downloads = "https://downloads.haskell.org/ghc";
in
{

  ghc_8_8_2_rc1 = fromBindist {
    url = "${downloads}/8.8.2-rc1/ghc-8.8.1.20191211-x86_64-fedora27-linux.tar.xz";
    sha256 = "122z44c7dhl01ixdxkz01p9s5v9z4zds6h8jjsf9y5qal1p6pmzl";
  };

  ghc_8_10_1_alpha1 = fromBindist {
    url = "${downloads}/8.10.1-alpha1/ghc-8.10.0.20191121-x86_64-fedora27-linux.tar.xz";
    sha256 = "1a20mf89fhm9cr4m3hd38fylhfjr872nhv067zcbyqf99a93nby8";
  };

  ghc_8_10_1_alpha2 = fromBindist {
    url = "${downloads}/8.10.1-alpha2/ghc-8.10.0.20191210-x86_64-fedora27-linux.tar.xz";
    sha256 = "1gvr12rng3dib93zaprnl301k2pzwpc036b1piy5s851qw99vjlr";
  };
}
