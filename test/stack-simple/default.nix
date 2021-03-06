{ stdenv, mkStackPkgSet }:

with stdenv.lib;

let
  # ./stack-pkgs.nix and ./.stack.nix/stack-simple are
  # generated by running hpack then stack-to-nix.
  pkgSet = mkStackPkgSet {
    stack-pkgs = import ./stack-pkgs.nix;
    pkg-def-overlays = [];
    modules = [];
  };

  packages = pkgSet.config.hsPkgs;

in
  stdenv.mkDerivation {
    name = "stack-simple-test";

    buildCommand = ''
      exe="${packages.stack-simple.components.exes.stack-simple-exe}/bin/stack-simple-exe"

      printf "checking whether executable runs... " >& 2
      $exe

      touch $out
    '';

    meta.platforms = platforms.all;

    passthru = {
      # Attributes used for debugging with nix repl
      inherit pkgSet packages;
    };
  }
