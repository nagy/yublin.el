{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  emacs ? pkgs.emacs,
  emacsPackages ? emacs.pkgs,
  melpaBuild ? emacsPackages.melpaBuild,
}:

melpaBuild (finalAttrs: {
  pname = "yublin";
  version = "0.1.0";
  src = lib.cleanSource ./.;

  turnCompilationWarningToError = true;

  checkPhase = ''
    runHook preCheck
    emacs --batch -L . \
      -l yublin-tests.el \
      -f ert-run-tests-batch-and-exit
    runHook postCheck
  '';

  doCheck = true;

  meta = {
    description = "Yublin shorthand expansion for Emacs";
    longDescription = ''
      Yublin is a shorthand system for speed-writing that reduces the
      600 most common English words to 1- and 2-letter shortcuts.
      This package implements it as a buffer-local minor mode built on
      top of Emacs' abbrev-mode.  Typing a shortcut followed by a
      word-separator automatically expands it to the full word.
    '';
    license = lib.licenses.agpl3Plus;
    homepage = "https://github.com/nagy/yublin.el";
    maintainers = with lib.maintainers; [ nagy ];
    platforms = lib.platforms.unix;
  };
})
