# AGENTS.md — yublin.el

## Purpose

`yublin.el`: Emacs Lisp package that implements the Yublin speed-writing shorthand,
600 common English words reduced to 1- and 2-letter shortcuts, as a buffer-local
minor mode built on `abbrev-mode`. Emacs 28.1 or newer. License:
AGPL-3.0-or-later.

## Layout

- `yublin.el` — the package: dictionary, abbrev tables, minor mode, joined-word
  guard, region toggle, evil operator.
- `test/yublin-test.el` — the ERT suite, 54 tests. Must stay green. One test file
  per source file, named `<unit>-test.el`. The flake loads `test/*-test.el` by
  glob, so a new test file needs no flake edit. Shared helpers would go in
  `test/yublin-test-helper.el`, which must not match `*-test.el`.
- `flake.nix` — flake-parts plus `melpaBuild`. Runs the ERT suite in `checkPhase`
  with byte-compile warnings as errors (`doCheck = true`). `checks.lint` gates
  package-lint and checkdoc on `*.el test/*.el`, and allowlists the
  `eval-after-load` finding for the optional evil integration on purpose.

## Build and test

- `nix flake check` — the gate. Run before done.
- `nix build` — the package. The checkPhase runs the suite.
- `nix fmt` — nixfmt through treefmt.
- `emacs --batch -L . -L test -l test/yublin-test.el -f
  ert-run-tests-batch-and-exit` — run the tests in the dev environment (Emacs 31).
- `emacs --batch -L . -f batch-byte-compile yublin.el` — byte-compile check.

## Rules

- Keep the shortcut set letter-only and 1 to 2 characters. Expansions may hold
  apostrophes. Do not add a shortcut that holds an apostrophe. Contractions carry
  dedicated letter-only shortcuts such as `dt`, `gb` and `ll`.
- Keep the one deliberate duplicate: `standing` maps to both `cq` and `oq`. The
  encode table resolves it last-wins to `oq`, and both decode back. The
  `yublin-dictionary-standing-has-two-shortcuts` test pins it. Do not "fix" it.
- Keep encode and decode symmetric. Contractions stay whole tokens in both
  directions, and decode never expands a letter adjacent to an apostrophe.
- Ship an ERT regression test with every behaviour change. Prefix every
  `ert-deftest` name with `yublin-`, test files included, so the lint gate stays
  strict.
- Do not hand-bump the version. The flake derives `0-unstable-YYYY-MM-DD` from
  `self.lastModifiedDate`, with an epoch fallback for non-git sources.
- Do not commit generated artifacts. `GENERAL_RECOMMENDATIONS.org` is the review
  document, and its `.pdf` and `.html` files come from it and stay untracked.

## Conventions

- `lexical-binding: t` in both files. The package carries no other dependency.
- Keep docstrings clean under checkdoc.
- The dictionary stays inline data in `yublin--dictionary`, 619 entries.
