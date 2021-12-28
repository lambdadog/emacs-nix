let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    overlays = [ (import sources.emacs-overlay) ];
  };

  inherit (pkgs) emacsPackagesFor;

  emacsWithConfig = emacsPackages: { emacsDir, init, earlyInit ? null }:
    # It'd be both an easy to make and bad mistake to pass a path here
    assert builtins.isString emacsDir;

    let
      emacs-nix-config = emacsPackages.trivialBuild {
        pname = "emacs-nix-config";

        packageRequires = (pkgs.lib.lists.optional (! isNull earlyInit) earlyInit) ++ [
          init
        ];

        src = pkgs.writeTextFile {
          name = "emacs-nix-config-src";

          destination = "/emacs-nix-config.el";

          text = ''
            ;; -*- lexical-binding: t -*-
            (defconst emacs-nix-config--user-emacs-directory "${emacsDir}")
            ${pkgs.lib.optionalString (! isNull earlyInit) "(defconst emacs-nix-config--early-init \"${earlyInit.pname}\")"}
            (defconst emacs-nix-config--init "${init.pname}")
            (provide 'emacs-nix-config)
          '';
        };
      };
    in (emacsPackages.withPackages [ emacs-nix-config ]).overrideAttrs (_: {
      name = (pkgs.appendToName "with-config" emacsPackages.emacs).name;
    });

  selectPatches = with pkgs; version: let
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
  in patches."${versionKey}";

  mkNixEmacs = oldPkg: let
    result = oldPkg.overrideAttrs (old: {
      name = (pkgs.appendToName "nix" oldPkg).name;

      patches = (old.patches or []) ++ (selectPatches oldPkg.version);
    });
  in result;

  mkNixEmacsTree = emacs: rec {
    raw = mkNixEmacs emacs;
    packages = emacsPackagesFor raw;
    withConfig = emacsWithConfig packages;
  };
in {
  emacs         = mkNixEmacsTree pkgs.emacs;
  emacsGit      = mkNixEmacsTree pkgs.emacsGit;
  emacsGcc      = mkNixEmacsTree pkgs.emacsGcc;
  emacsPgtk     = mkNixEmacsTree pkgs.emacsPgtk;
  emacsPgtkGcc  = mkNixEmacsTree pkgs.emacsPgtkGcc;
  emacsUnstable = mkNixEmacsTree pkgs.emacsUnstable;
}


