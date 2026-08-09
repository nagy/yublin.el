# AGENTS.md

## Project

yublin.el: an Emacs Lisp package implementing the Yublin speed-writing
shorthand (600 common English words reduced to 1- and 2-letter
shortcuts) as a buffer-local minor mode built on Emacs' `abbrev-mode`.
Requires Emacs 28.1+. License: AGPL-3.0-or-later.

## Layout

- `yublin.el` — the package (dictionary, abbrev tables, minor mode,
  joined-word guard, region toggle, evil operator).
- `yublin-tests.el` — the ert suite (52 tests). Must stay green.
- `default.nix` — melpaBuild derivation; runs the ert suite in
  `checkPhase` with byte-compile warnings as errors.

## Commands

Run the tests (dev environment, Emacs 31):

```
emacs --batch -L . -l yublin-tests.el -f ert-run-tests-batch-and-exit
```

Byte-compile check:

```
emacs --batch -L . -f batch-byte-compile yublin.el
```

Full build gate (uses Nix, Emacs 30.2, native-comp + checkPhase):

```
nix-build default.nix
```

## Conventions

- `lexical-binding: t` in both files; no other dependencies.
- Docstrings must pass `checkdoc`; keep them clean.
- Dictionary is inline data in `yublin--dictionary` (619 entries).
  Shortcuts are 1-2 letters, letter-only; expansions may contain
  apostrophes (contractions have dedicated letter-only shortcuts such as
  `dt`, `gb`, `ll`). Do not add shortcuts containing apostrophes.
- Encode and decode must stay symmetric: contractions are whole tokens
  in both directions; decode must never expand a letter adjacent to an
  apostrophe.
- Behavior changes ship with ert regression tests in `yublin-tests.el`.
- Do not commit generated artifacts (`GENERAL_RECOMMENDATIONS.org` is
  the review document; its `.pdf`/`.html` are regenerated from it and
  not tracked).
