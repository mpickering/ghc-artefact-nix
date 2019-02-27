{ stdenv }:
{ branch, fork }:

let
  mkUrl = job: "https://gitlab.haskell.org/${fork}/ghc/-/jobs/artifacts/${branch}/raw/ghc.tar.xz?job=${job}";
  url = {
    "i386-linux"   = {
      url = mkUrl "validate-i386-linux-deb9";
    };
    "x86_64-linux" = {
      url = mkUrl "validate-x86_64-linux-deb8";
    };
    "aarch64-linux" = {
      url = mkUrl "validate-aarch64-linux-deb9";
    };
    "x86_64-darwin" = {
      url = mkUrl "validate-x86_64-darwin";
    };
  }.${stdenv.hostPlatform.system}
    or (throw "cannot bootstrap GHC on this platform");
in builtins.fetchurl url

