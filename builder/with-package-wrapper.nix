# This is a simplified version of the ghcWithPackages wrapper in
# nixpkgs, adapted to work with the package database of a single
# component.
{ lib, stdenv, ghc, runCommand, lndir, makeWrapper
}:

{ package
, configFiles
, postBuild ? ""
}:

let
  isGhcjs       = ghc.isGhcjs or false;
  ghcCommand'    = if isGhcjs then "ghcjs" else "ghc";
  ghcCommand = "${ghc.targetPrefix}${ghcCommand'}";
  ghcCommandCaps= lib.toUpper ghcCommand';
  libDir        = "$out/lib/${ghcCommand}-${ghc.version}";
  docDir        = "$out/share/doc/ghc/html";
  packageCfgDir = "${libDir}/package.conf.d";

in runCommand "${ghc.name}-with-${package.identifier.name}" {
  preferLocalBuild = true;
  passthru = {
    inherit (ghc) version meta;
    baseGhc = ghc;
    inherit package;
  };
} (
  ''
    . ${makeWrapper}/nix-support/setup-hook

    # Start with a ghc...
    mkdir -p $out/bin
    ${lndir}/bin/lndir -silent ${ghc} $out

    # ...and replace package database with the one from target package config.
    rm -rf ${libDir}/*/
    ln -s ${configFiles}/package.conf.d ${packageCfgDir}

    # Wrap compiler executables with correct env variables.
    # The NIX_ variables are used by the patched Paths_ghc module.

    for prg in ${ghcCommand} ${ghcCommand}i ${ghcCommand}-${ghc.version} ${ghcCommand}i-${ghc.version}; do
      if [[ -x "${ghc}/bin/$prg" ]]; then
        rm -f $out/bin/$prg
        makeWrapper ${ghc}/bin/$prg $out/bin/$prg                           \
          --add-flags '"-B$NIX_${ghcCommandCaps}_LIBDIR"'                   \
          --set "NIX_${ghcCommandCaps}"        "$out/bin/${ghcCommand}"     \
          --set "NIX_${ghcCommandCaps}PKG"     "$out/bin/${ghcCommand}-pkg" \
          --set "NIX_${ghcCommandCaps}_DOCDIR" "${docDir}"                  \
          --set "NIX_${ghcCommandCaps}_LIBDIR" "${libDir}"
      fi
    done

    for prg in runghc runhaskell; do
      if [[ -x "${ghc}/bin/$prg" ]]; then
        rm -f $out/bin/$prg
        makeWrapper ${ghc}/bin/$prg $out/bin/$prg                           \
          --add-flags "-f $out/bin/${ghcCommand}"                           \
          --set "NIX_${ghcCommandCaps}"        "$out/bin/${ghcCommand}"     \
          --set "NIX_${ghcCommandCaps}PKG"     "$out/bin/${ghcCommand}-pkg" \
          --set "NIX_${ghcCommandCaps}_DOCDIR" "${docDir}"                  \
          --set "NIX_${ghcCommandCaps}_LIBDIR" "${libDir}"
      fi
    done

    # Point ghc-pkg to the package database of the component using the
    # --global-package-db flag.

    for prg in ${ghcCommand}-pkg ${ghcCommand}-pkg-${ghc.version}; do
      if [[ -x "${ghc}/bin/$prg" ]]; then
        rm -f $out/bin/$prg
        makeWrapper ${ghc}/bin/$prg $out/bin/$prg --add-flags "--global-package-db=${packageCfgDir}"
      fi
    done

    # fixme: check if this is needed
    # haddock was referring to the base ghc, https://github.com/NixOS/nixpkgs/issues/36976
    if [[ -x "${ghc}/bin/haddock" ]]; then
      rm -f $out/bin/haddock
      makeWrapper ${ghc}/bin/haddock $out/bin/haddock    \
        --set "NIX_${ghcCommandCaps}_LIBDIR" "${libDir}"
    fi
  ''
)
