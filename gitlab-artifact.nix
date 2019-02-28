{ stdenv }:
{ branch, fork }:

let
  mkUrl = job: "https://gitlab.haskell.org/${fork}/ghc/-/jobs/artifacts/${branch}/raw/ghc.tar.xz?job=${job}";

  # job: the GitLab CI job we should pull the bindist from
  # ncursesVersion: the ncurses version which the bindist expects
  configs = {
    "i386-linux"   = {
      job = mkUrl "validate-i386-linux-fedora27";
      ncursesVersion = "6";
    };
    "x86_64-linux" = {
      job = mkUrl "validate-x86_64-linux-fedora27";
      ncursesVersion = "6";
    };
    "aarch64-linux" = {
      job = mkUrl "validate-aarch64-linux-deb9";
      ncursesVersion = "5";
    };
    "x86_64-darwin" = {
      job = mkUrl "validate-x86_64-darwin";
      ncursesVersion = "6";
    };
  };

  config = configs.${stdenv.hostPlatform.system}
    or (throw "cannot bootstrap GHC on this platform");

in {
  bindistTarball = builtins.fetchurl (mkUrl config.job);
  inherit (config) ncursesVersion;
}

