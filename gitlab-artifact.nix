{ stdenv }:
{ branch, fork }:

let
  mkUrl = config: "https://gitlab.haskell.org/${fork}/ghc/-/jobs/artifacts/${branch}/raw/${config.tarball}?job=${config.job}";

  # job: the GitLab CI job we should pull the bindist from
  # ncursesVersion: the ncurses version which the bindist expects
  configs = {
    "i386-linux"   = {
      job = "i386-linux-deb9-validate";
      tarball = "ghc-i386-linux-deb9-validate.tar.gz";
      ncursesVersion = "6";
    };
    "x86_64-linux" = {
      job = "x86_64-linux-fedora33-release";
      tarball = "ghc-x86_64-linux-fedora33-release.tar.xz";
      ncursesVersion = "6";
    };
    "aarch64-linux" = {
      job = "aarch64-linux-deb10-validate";
      ncursesVersion = "5";
    };
    "x86_64-darwin" = {
      job = "x86_64-darwin-validate";
      tarball = "ghc-x86_64-darwin-validate.tar.xz";
      ncursesVersion = "6";
    };
  };

  config = configs.${stdenv.hostPlatform.system}
    or (throw "cannot bootstrap GHC on this platform");

in {
  bindistTarball = builtins.fetchurl (mkUrl config);
  inherit (config) ncursesVersion;
}

