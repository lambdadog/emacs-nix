# `emacsWithConfig`
A nix tool to enable providing your emacs config via Nix.
## Usage
It's recommended to use the [`emacs-nix` Cachix
cache](https://app.cachix.org/cache/emacs-nix#pull) when using
`emacsWithConfig`, although only if you're using the "golden" versions
of emacs provided by this repository.

Using `emacsWithConfig` requires providing your emacs config as a
well-formed emacs package derivation. This involves several things:
 + Using `provide` statements, so your init registers a feature.
 + Ensuring your derivation's `pname` is the same as your package
   name.
 + Ensuring your package (and feature) name is the same as the
   filename of its entrypoint.
   
My personal convention is to call my init package `config-init`, which
means:
 + The derivation's pname is "config-init".
 + The derivation's source tree contains `config-init.el` as its
   entrypoint.
 + `config-init.el` contains `(provide 'config-init)` at the bottom of
   the file.

Then to use this config-init package with pure-GTK emacs with native
compilation, and with an emacsDir in `~/.local/share/emacs/`, assuming
this package can be found at `./config-init`, I would call
`emacsWithConfig` as follows:

```nix
with emacsNix; emacsWithConfig emacsVersions.emacsPgtkGcc {
  emacsDir = "~/.local/share/emacs/";
  init = ep: ep.callPackage ./config-init {};
}
```

Fetching `emacsWithConfig` can be done however you wish. I personally
use [niv](https://github.com/nmattia/niv) to manage my dependencies,
but you can trivially also use `fetchGit`, `fetchGitHub` or
`fetchTarball`.
### "Golden" versions of emacs
`emacsWithConfig` provides several "golden" versions of emacs in the
`emacsVersions` set, so called because their patched versions should
always be cached via CI in the `emacs-nix` Cachix cache.

These golden versions are provided via `emacsWithConfig`'s own Niv
pins of both Nixpkgs and the nix-community
[emacs-overlay](https://github.com/nix-community/emacs-overlay).

If desired, you may provide your own emacs derivation or override the
existing ones. To do so, simply pass your emacs derivation to the
`emacsWithConfig` function.

Note that `emacsWithConfig` functions via patches to emacs, therefore
if you also patch emacs (specifically `lisp/startup.el`) there may be
a chance of collisions. These patches support emacs 27, emacs 28, and
the git master version of emacs as well as possible, although
successful builds can only be guaranteed if you're using the provided
golden versions. All overrides are also recommended to be based on
said golden versions, to ensure the highest chance of successful builds.
