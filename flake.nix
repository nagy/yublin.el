{
  description = "Yublin shorthand expansion for Emacs (Emacs package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Emacs packages are pure Elisp: no ELF binaries, so evaluate on
      # every Linux arch (and darwin if the deps exist there).
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          system,
          pkgs,
          lib,
          config,
          ...
        }:
        let
          inherit (pkgs.emacsPackages) melpaBuild;
        in
        {
          packages.yublin = melpaBuild {
            pname = "yublin";
            # Nix rejects versions Nixpkgs cannot parse. Convention for
            # unreleased packages: <upstream-version>-unstable-<YYYY-MM-DD>,
            # where the date is the last commit touching the source.
            version = "0.1.0-unstable-2026-08-09";

            src = lib.cleanSource ./.;

            # No external Elisp dependencies: Package-Requires is empty
            # (built on abbrev-mode, shipped with Emacs itself).
            # packageRequires = with pkgs.emacsPackages; [ ];

            # The ert suite ships with the package; run it in checkPhase
            # so `nix build` fails on regressions, exactly like the old
            # default.nix gate did.
            checkPhase = ''
              runHook preCheck
              emacs --batch -L . \
                -l yublin-tests.el \
                -f ert-run-tests-batch-and-exit
              runHook postCheck
            '';

            doCheck = true;

            # Byte-compilation warnings fail the build. Keep it on: it is
            # the cheapest lint the package will ever get. Silence only
            # genuinely noisy third-party warnings, never your own code.
            turnCompilationWarningToError = true;

            meta = {
              description = "Yublin shorthand expansion for Emacs";
              # 2–5 sentences: what it does, how (which Emacs primitives /
              # external services), and any notable modes of operation.
              longDescription = ''
                Yublin is a shorthand system for speed-writing that reduces the
                600 most common English words to 1- and 2-letter shortcuts.
                This package implements it as a buffer-local minor mode built on
                top of Emacs' abbrev-mode.  Typing a shortcut followed by a
                word-separator automatically expands it to the full word.
              '';
              # Read the license from the file header — Elisp packages
              # conventionally declare it after ";;; Code:".
              license = lib.licenses.agpl3Plus;
              homepage = "https://github.com/nagy/yublin.el";
              maintainers = with lib.maintainers; [ nagy ];
              platforms = lib.platforms.unix;
            };
          };

          packages.default = config.packages.yublin;

          checks.default = config.packages.yublin;

          devShells.default = pkgs.mkShell {
            # A real Emacs for interactive testing of the package while
            # hacking on it.
            packages = [
              pkgs.emacs
            ];
          };
        };
    };
}
