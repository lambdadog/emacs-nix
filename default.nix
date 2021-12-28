let
  sources = import ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    overlays = [ (import sources.emacs-overlay) ];
  };

  inherit (pkgs) emacsPackagesFor;

  emacsWithConfig = emacs: { emacsDir, earlyInit ? null , init }: let
    emacsPackages = (emacsPackagesFor emacs);

    emacs-nix-config = emacsPackages.trivialBuild {
      # makes emacsWithPackages generate a nifty derivation name
      pname = "with-config";

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
  in emacsPackages.withPackages [ emacs-nix-config ];

  mkNixEmacs = oldPkg: let
    result = oldPkg.overrideAttrs (old: {
      name = "${oldPkg.pname}-nix-${oldPkg.version}";

      patches = (old.patches or []) ++ [
        ./patches/0001-Add-nix-loader.patch
        ./patches/0002-Load-autoloads.patch
        ./patches/0003-Setup-custom-file.patch
      ];
    });
  in result;

  mkNixEmacsTree = emacs: let
    nixEmacs = mkNixEmacs emacs;
  in {
    raw = nixEmacs;
    withConfig = emacsWithConfig nixEmacs;
    packages = emacsPackagesFor nixEmacs;
  };
in {
  emacs         = mkNixEmacsTree pkgs.emacs;
  emacsGit      = mkNixEmacsTree pkgs.emacsGit;
  emacsGcc      = mkNixEmacsTree pkgs.emacsGcc;
  emacsPgtk     = mkNixEmacsTree pkgs.emacsPgtk;
  emacsPgtkGcc  = mkNixEmacsTree pkgs.emacsPgtkGcc;
  emacsUnstable = mkNixEmacsTree pkgs.emacsUnstable;
}


