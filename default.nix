let
  sources = import ./nix/sources.nix;

  vendoredPkgs = system: import sources.nixpkgs {
    overlays = [ (import sources.emacs-overlay) ];
    inherit system;
  };
in
{ pkgs ? null
, system ? if isNull pkgs then builtins.currentSystem else pkgs.system
, ci ? false
}:

with (if isNull pkgs then vendoredPkgs system else pkgs);

let
  emacsWithConfig = emacsPkg: { emacsDir, init, earlyInit ? null }:
    # Ensure a string path is used rather than a nix path and that
    # said path ends with "/" (emacs uses concatenation for operations
    # on paths, so directory paths ending in "/" is essential).
    #
    # When a nix path is used, it's copied to the nix store prior to
    # substitution and therefore wouldn't function as expected as an
    # emacs dir.
    assert builtins.isString emacsDir
      && builtins.substring ((builtins.stringLength emacsDir) - 1) 1 emacsDir == "/";

    let
      # Apply our patches.
      nixEmacs = mkNixEmacs emacsPkg;

      nixEmacsPackages = emacsPackagesFor nixEmacs;

      emacs-nix-config = let
        earlyInitPkg =
          if isNull earlyInit
          then null
          else earlyInit nixEmacsPackages;
        initPkg = init nixEmacsPackages;
      in
        assert lib.isDerivation earlyInitPkg || isNull earlyInitPkg;
        assert lib.isDerivation initPkg;

        nixEmacsPackages.trivialBuild {
          pname = "${emacsPkg.version}-emacs-nix-config";

          packageRequires = (lib.lists.optional (! isNull earlyInit) earlyInitPkg) ++ [
            initPkg
          ];

          src = writeTextFile {
            name = "emacs-nix-config-src";

            destination = "/emacs-nix-config.el";

            text = ''
              ;; -*- lexical-binding: t -*-
              (defconst emacs-nix-config--user-emacs-directory "${emacsDir}")
              ${lib.optionalString (! isNull earlyInit) "(defconst emacs-nix-config--early-init \"${earlyInitPkg.pname}\")"}
              (defconst emacs-nix-config--init "${initPkg.pname}")
              (provide 'emacs-nix-config)
            '';
          };
        };
    in (nixEmacsPackages.withPackages [ emacs-nix-config ]).overrideAttrs (_: {
      name = (appendToName "with-config" emacsPkg).name;
    });

  selectPatches = version: let
    majorVersion = lib.versions.major version;
    versionKey =
      # Detect if the major version is a date, indicating a build off
      # of the master branch.
      if builtins.stringLength majorVersion == 8
      then "master"
      else majorVersion;

    patches = let
      dirToPatches = versionDir: let
        patchNames = lib.attrNames (builtins.readDir (./patches + "/${versionDir}"));
      in map (name: ./patches + "/${versionDir}/${name}") patchNames;
    in lib.attrsets.mapAttrs (name: _: dirToPatches name) (builtins.readDir ./patches);
  in if lib.hasAttr versionKey patches
     then patches."${versionKey}"
     else throw "emacsWithConfig does not have patches for emacs version \"${versionKey}\"";

  mkNixEmacs = oldPkg: let
    result = oldPkg.overrideAttrs (old: {
      name = (appendToName "nix" oldPkg).name;

      patches = (old.patches or []) ++ (selectPatches oldPkg.version);
    });
  in result;

  emacsVersions = {
    inherit (vendoredPkgs system)
      emacs emacsGit emacsGcc emacsPgtk emacsPgtkGcc emacsUnstable;
  };
in
if ci
then lib.mapAttrs (_: pkg: mkNixEmacs pkg) emacsVersions
else {
  inherit emacsVersions emacsWithConfig;
}
