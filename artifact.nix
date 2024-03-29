{ stdenv, lib, patchelf
, perl, gcc, gcc-unwrapped, llvm
, ncurses6, ncurses5, gmp, glibc, libiconv, numactl
}: { bindistTarball, ncursesVersion }:

# Prebuilt only does native
assert stdenv.targetPlatform == stdenv.hostPlatform;

let
  libPath = lib.makeLibraryPath ([
    selectedNcurses gmp numactl
  ] ++ lib.optional (stdenv.hostPlatform.isDarwin) libiconv);

  selectedNcurses = {
    "5" = ncurses5;
    "6" = ncurses6;
  }."${ncursesVersion}";

  libEnvVar = lib.optionalString stdenv.hostPlatform.isDarwin "DY"
    + "LD_LIBRARY_PATH";

  glibcDynLinker = assert stdenv.isLinux;
    if stdenv.hostPlatform.libc == "glibc" then
       # Could be stdenv.cc.bintools.dynamicLinker, keeping as-is to avoid rebuild.
       ''"$(cat $NIX_CC/nix-support/dynamic-linker)"''
    else
      "${lib.getLib glibc}/lib/ld-linux*";

  # Figure out version of bindist
  version =
    let
      helper = stdenv.mkDerivation {
        name = "bindist-version";
        src = bindistTarball;
        nativeBuildInputs = [ gcc perl ];
        buildPhase = ''
          # Run it twice since make might produce related output the first time.
          make show VALUE=ProjectVersion
          make show VALUE=ProjectVersion > version
        '';
        installPhase = ''
          source version
          echo -n "$ProjectVersion" > $out
        '';
      };
    in lib.readFile helper;
in

stdenv.mkDerivation rec {
  inherit version;

  name = "ghc-${version}";

  src = bindistTarball;

  nativeBuildInputs = [ perl ];
  buildInputs = lib.optionals (stdenv.targetPlatform.isAarch32 || stdenv.targetPlatform.isAarch64) [ llvm ];

  # Cannot patchelf beforehand due to relative RPATHs that anticipate
  # the final install location/
  ${libEnvVar} = libPath;

  preferLocalBuild = true;

  postUnpack =
    # GHC has dtrace probes, which causes ld to try to open /usr/lib/libdtrace.dylib
    # during linking
    lib.optionalString stdenv.isDarwin ''
      export NIX_LDFLAGS+=" -no_dtrace_dof"
      # not enough room in the object files for the full path to libiconv :(
      for exe in $(find . -type f -executable); do
        isScript $exe && continue
        ln -fs ${libiconv}/lib/libiconv.dylib $(dirname $exe)/libiconv.dylib
        install_name_tool -change /usr/lib/libiconv.2.dylib @executable_path/libiconv.dylib -change /usr/local/lib/gcc/6/libgcc_s.1.dylib ${gcc.cc.lib}/lib/libgcc_s.1.dylib $exe
      done
    '' +

    # Some scripts used during the build need to have their shebangs patched
    ''
      patchShebangs ghc*/utils/
      patchShebangs ghc*/configure
    '' +

    # Strip is harmful, see also below. It's important that this happens
    # first. The GHC Cabal build system makes use of strip by default and
    # has hardcoded paths to /usr/bin/strip in many places. We replace
    # those below, making them point to our dummy script.
    ''
      mkdir "$TMP/bin"
      for i in strip; do
        echo '#! ${stdenv.shell}' > "$TMP/bin/$i"
        chmod +x "$TMP/bin/$i"
      done
      PATH="$TMP/bin:$PATH"
    '' +
    # We have to patch the GMP paths for the integer-gmp package.
    ''
      find . -name integer-gmp.buildinfo \
          -exec sed -i "s@extra-lib-dirs: @extra-lib-dirs: ${gmp.out}/lib@" {} \;
      find . -name ghc-bignum.buildinfo \
          -exec sed -i "s@extra-lib-dirs: @extra-lib-dirs: ${gmp.out}/lib@" {} \;
    '' + lib.optionalString stdenv.isDarwin ''
      find . -name base.buildinfo \
          -exec sed -i "s@extra-lib-dirs: @extra-lib-dirs: ${libiconv}/lib@" {} \;
    '' +
    # Rename needed libraries and binaries, fix interpreter
    # N.B. Use patchelfUnstable due to https://github.com/NixOS/patchelf/pull/85
    lib.optionalString stdenv.isLinux ''
      find . -type f -perm -0100 -exec ${patchelf}/bin/patchelf \
          --replace-needed libncurses${lib.optionalString stdenv.is64bit "w"}.so.${ncursesVersion} libncurses.so \
          --replace-needed libtinfo.so.${ncursesVersion} libncurses.so.${ncursesVersion} \
          --interpreter ${glibcDynLinker} {} \;

      # text-2.0 links against libstdc++
      find . -type f -perm -0100 -exec ${patchelf}/bin/patchelf \
          --add-rpath ${gcc-unwrapped.lib}/lib \
          {} \;

      sed -i "s|/usr/bin/perl|perl\x00        |" ghc*/ghc/stage2/build/tmp/ghc-stage2 || true
      sed -i "s|/usr/bin/gcc|gcc\x00        |" ghc*/ghc/stage2/build/tmp/ghc-stage2 || true
    '';

  configurePlatforms = [ ];
  configureFlags = [
    "--with-gmp-libraries=${lib.getLib gmp}/lib"
    "--with-gmp-includes=${lib.getDev gmp}/include"
  ] ++ lib.optional stdenv.isDarwin "--with-gcc=${./gcc-clang-wrapper.sh}"
    ++ lib.optional stdenv.hostPlatform.isMusl "--disable-ld-override";

  # Stripping combined with patchelf breaks the executables (they die
  # with a segfault or the kernel even refuses the execve). (NIXPKGS-85)
  dontStrip = true;

  # No building is necessary, but calling make without flags ironically
  # calls install-strip ...
  dontBuild = true;

  # On Linux, use patchelf to modify the executables so that they can
  # find editline/gmp.
  preFixup = lib.optionalString stdenv.isLinux ''
    for p in $(find "$out" -type f -executable); do
      if isELF "$p"; then
        echo "Patchelfing $p"
        patchelf --set-rpath "${libPath}:$(patchelf --print-rpath $p)" $p
      fi
    done
  '' + lib.optionalString stdenv.isDarwin ''
    # not enough room in the object files for the full path to libiconv :(
    for exe in $(find "$out" -type f -executable); do
      isScript $exe && continue
      ln -fs ${libiconv}/lib/libiconv.dylib $(dirname $exe)/libiconv.dylib
      install_name_tool -change /usr/lib/libiconv.2.dylib @executable_path/libiconv.dylib -change /usr/local/lib/gcc/6/libgcc_s.1.dylib ${gcc.cc.lib}/lib/libgcc_s.1.dylib $exe
    done

    for file in $(find "$out" -name setup-config); do
      substituteInPlace $file --replace /usr/bin/ranlib "$(type -P ranlib)"
    done
  '';

  postInstall = lib.optionalString stdenv.isLinux ''
    # Fix dependencies on libtinfo in package registrations.
    for f in $(find "$out" -type f -iname '*.conf'); do
        echo "Fixing tinfo dependency in $f..."
        #sed -i "s/extra-libraries: *tinfo/extra-libraries: ncurses\n/" $f
        echo "library-dirs: ${selectedNcurses}/lib" >> $f
        echo "dynamic-library-dirs: ${selectedNcurses}/lib" >> $f
        echo "Fixing gmp dependency in $f..."
        echo "library-dirs: ${gmp.out}/lib" >> $f
        echo "dynamic-library-dirs: ${gmp.out}/lib" >> $f
        echo "Fixing numa dependency in $f..."
        echo "library-dirs: ${numactl.out}/lib" >> $f
        echo "dynamic-library-dirs: ${numactl.out}/lib" >> $f
    done
    $out/bin/ghc-pkg recache
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    unset ${libEnvVar}
    # Sanity check, can ghc create executables?
    cd $TMP
    mkdir test-ghc; cd test-ghc
    cat > main.hs << EOF
      {-# LANGUAGE TemplateHaskell #-}
      module Main where
      main = putStrLn \$([|"yes"|])
    EOF
    $out/bin/ghc --make main.hs || exit 1
    echo compilation ok
    [ $(./main) == "yes" ]
  '';

  passthru = {
    targetPrefix = "";
    enableShared = true;
    haskellCompilerName = "ghc-${version}";
  };

  meta.license = lib.licenses.bsd3;
  meta.platforms = ["x86_64-linux" "i686-linux" "x86_64-darwin" "armv7l-linux" "aarch64-linux"];
}
