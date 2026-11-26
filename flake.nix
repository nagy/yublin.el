{
  description = "Yublin shorthand expansion for Emacs (Emacs package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
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
            preferLocalBuild = true;
            # Nix rejects versions Nixpkgs cannot parse. Convention for
            # unreleased packages: <upstream-version>-unstable-<YYYY-MM-DD>,
            # where the date is the last commit touching the source.
            # Derive the date from the flake self-reference. Fall back to
            # the epoch when the source is not a git checkout.
            version =
              let
                d = self.lastModifiedDate or "19700101000000";
              in
              "0-unstable-${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}";

            src = lib.cleanSource ./.;

            # No external Elisp dependencies: Package-Requires is empty
            # (built on abbrev-mode, shipped with Emacs itself).
            # packageRequires = with pkgs.emacsPackages; [ ];

            # The ert suite ships with the package; run it in checkPhase
            # so `nix build` fails on regressions, exactly like the old
            # default.nix gate did.
            #
            # melpaBuild stages root-level *.el only (its `files' default),
            # so the test tree has to be copied back in before it can be
            # loaded.  The glob keeps a new test file from needing a flake
            # edit: printf repeats "-l %s" per match, failglob makes an
            # empty glob a shell error so the `||' guard fires instead of
            # running zero tests, and the unquoted $test_args is what
            # splits it into `-l <file>' pairs.
            checkPhase = ''
              runHook preCheck
              cp -r ${./test} ./test
              shopt -s failglob
              test_args=$(printf -- "-l %s " test/*-test.el) || { echo 'no tests matched test/*-test.el' >&2; exit 1; }
              shopt -u failglob
              emacs --batch -L . -L test $test_args \
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

          # Lint gate: checkdoc + package-lint. Both catch what
          # byte-compilation cannot (docstring style, package metadata,
          # prefix conventions). Findings fail the build.
          checks.lint =
            pkgs.runCommandLocal "yublin-lint"
              {
                nativeBuildInputs = [
                  (pkgs.emacsPackages.emacsWithPackages (p: [ p.package-lint ]))
                ];
                src = config.packages.yublin.src;
                meta.description = "checkdoc and package-lint gate for yublin";
              }
              ''
              export HOME=$TMPDIR
              # The test tree is part of the lint surface, so copy the whole
              # source tree rather than the single staged file.
              cp -r "$src"/. .
              # package-lint assumes online ELPA.  Offline it needs
              # stubs: extend `package-lint--sane-prefixes' where
              # symbols use a different prefix than the file name
              # suggests (here: the evil operator), and add missing deps
              # via :after advice on `package-initialize' — it nils
              # `package-alist' on every call, so plain push before
              # -f package-lint-batch-and-exit gets wiped.
              #
              # `package-lint-main-file' is mandatory once test/*.el joins
              # the glob: without it package-lint treats each test file as
              # its own package and asks for a Package-Requires header.
              #
              # Warnings are made non-fatal and the output is gated by
              # hand instead, so one documented exception (below) can be
              # allowlisted without weakening everything else.
              pl_log=$(emacs --batch -l package-lint \
                --eval '(setq package-lint-main-file "yublin.el")' \
                --eval '(setq package-lint--sane-prefixes (concat package-lint--sane-prefixes "\\|evil-yublin"))' \
                --eval '(setq package-lint-batch-fail-on-warnings nil)' \
                -f package-lint-batch-and-exit *.el test/*.el 2>&1 || true)
              # Accepted finding (documented exception): the optional
              # evil integration defers via `eval-after-load'; making
              # evil a hard dependency would be worse. "Entering
              # directory" is batch noise printed alongside findings.
              pl_log=$(printf '%s\n' "$pl_log" \
                | grep -v -e "^Entering directory" \
                          -e "eval-after-load' is for use" || true)
              if [ -n "$pl_log" ]; then printf '%s\n' "$pl_log"; exit 1; fi
              # checkdoc is built in but exits 0 on findings — gate on
              # non-empty output.  Test files are linted too, so they keep
              # the same header and docstring rules as the code under test.
              lint_log=$(emacs --batch -l checkdoc \
                --eval '(mapc (lambda (f) (checkdoc-file f)) command-line-args-left)' \
                *.el test/*.el 2>&1 || true)
              if [ -n "$lint_log" ]; then printf '%s\n' "$lint_log"; exit 1; fi
              touch $out
            '';

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
