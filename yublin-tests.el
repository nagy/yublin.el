;;; yublin-tests.el --- Tests for yublin -*- lexical-binding: t -*-

;; Copyright (C) 2026  Daniel Nagy

;; This file is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public
;; License along with this file.  If not, see
;; <https://www.gnu.org/licenses/>.

;;; Commentary:

;; To run these tests:
;;
;;   (require 'yublin)
;;   (require 'ert)
;;
;; Then: M-x ert RET

(require 'yublin)
(require 'ert)

;;; Dictionary integrity

(ert-deftest yublin-dictionary-no-duplicate-shortcuts ()
  "Each shortcut string appears at most once in the dictionary."
  (let ((seen (make-hash-table :test 'equal)))
    (dolist (entry yublin--dictionary)
      (let ((shortcut (car entry)))
        (should-not (gethash shortcut seen))
        (puthash shortcut t seen)))))

(ert-deftest yublin-dictionary-shortcuts-are-shorter ()
  "Every shortcut must be strictly shorter than its expansion."
  (dolist (entry yublin--dictionary)
    (let ((shortcut (car entry))
          (expansion (cdr entry)))
      (should (< (length shortcut) (length expansion))))))

(ert-deftest yublin-dictionary-shortcuts-save-at-least-two-chars ()
  "Every shortcut must save at least 2 characters.
This matches Jon Aquino's original design rule."
  (dolist (entry yublin--dictionary)
    (let* ((shortcut (car entry))
           (expansion (cdr entry))
           (saved (- (length expansion) (length shortcut))))
      (should (>= saved 2)))))

(ert-deftest yublin-dictionary-count ()
  "Ensure we have roughly 600 entries (the expected yublin dictionary size)."
  ;; Allow some tolerance for parsing differences from the PDF.
  (let ((count (length yublin--dictionary)))
    (should (>= count 590))
    (should (<= count 630))))

;;; Abbrev table construction

(ert-deftest yublin-abbrev-table-has-all-entries ()
  "The full abbrev table should contain all dictionary entries."
  (let ((dict-count (length yublin--dictionary))
        (table-count 0))
    (mapatoms (lambda (_) (setq table-count (1+ table-count)))
              yublin-abbrev-table)
    ;; +1 because the table itself contains an extra internal entry
    (should (>= table-count dict-count))))

(ert-deftest yublin-abbrev-table-no-single-excludes-1-letter ()
  "The no-single table should not contain any 1-letter shortcuts."
  (mapatoms
   (lambda (sym)
     (let ((name (symbol-name sym)))
       (when (and (> (length name) 0)
                  (not (string-prefix-p "yublin--" name)))
         (should (> (length name) 1)))))
   yublin-abbrev-table--no-single))

;;; Expansion

(defun yublin-test--expand (shortcut &optional use-full-table)
  "Insert SHORTCUT in a temp buffer with yublin enabled, then expand.
Returns the buffer contents after expansion.
If USE-FULL-TABLE is non-nil, use the table with single-letter shortcuts."
  (with-temp-buffer
    (setq-local local-abbrev-table
                (if use-full-table
                    yublin-abbrev-table
                  yublin-abbrev-table--no-single))
    (abbrev-mode 1)
    (insert shortcut)
    (expand-abbrev)
    (buffer-string)))

(ert-deftest yublin-expand-basic ()
  "Basic 2-letter shortcuts should expand correctly."
  (should (equal (yublin-test--expand "bc") "because"))
  (should (equal (yublin-test--expand "gd") "good"))
  (should (equal (yublin-test--expand "wl") "well"))
  (should (equal (yublin-test--expand "th") "there"))
  (should (equal (yublin-test--expand "kn") "know"))
  (should (equal (yublin-test--expand "tm") "them"))
  (should (equal (yublin-test--expand "yr") "year"))
  (should (equal (yublin-test--expand "sh") "should"))
  (should (equal (yublin-test--expand "tt") "thought")))

(ert-deftest yublin-expand-with-apostrophe ()
  "Shortcuts expanding to words with apostrophes should work."
  (should (equal (yublin-test--expand "ll") "I'll"))
  (should (equal (yublin-test--expand "cz") "it's"))
  (should (equal (yublin-test--expand "dt") "don't"))
  (should (equal (yublin-test--expand "wq") "he's"))
  (should (equal (yublin-test--expand "qz") "I've"))
  (should (equal (yublin-test--expand "db") "that's"))
  (should (equal (yublin-test--expand "lx") "there's")))

(ert-deftest yublin-expand-single-letter ()
  "Single-letter shortcuts expand when using the full table."
  (should (equal (yublin-test--expand "t" t) "the"))
  (should (equal (yublin-test--expand "n" t) "and"))
  (should (equal (yublin-test--expand "w" t) "was"))
  (should (equal (yublin-test--expand "b" t) "with"))
  (should (equal (yublin-test--expand "y" t) "you"))
  (should (equal (yublin-test--expand "v" t) "have"))
  (should (equal (yublin-test--expand "s" t) "she")))

(ert-deftest yublin-no-expand-single-letter-when-opt-out ()
  "When `yublin-enable-single-letter' is nil, single-letter shortcuts
should NOT expand."
  (should (equal (yublin-test--expand "t") "t"))
  (should (equal (yublin-test--expand "n") "n"))
  (should (equal (yublin-test--expand "y") "y")))

;;; Mode toggling

(ert-deftest yublin-mode-enable-disable ()
  "Enabling and disabling `yublin-mode' toggles abbrev behavior."
  (with-temp-buffer
    (let ((orig-abbrev-table local-abbrev-table))
      ;; Enable
      (yublin-mode 1)
      (should yublin-mode)
      (should abbrev-mode)
      (should (eq local-abbrev-table yublin-abbrev-table))
      ;; Disable
      (yublin-mode -1)
      (should-not yublin-mode)
      (should (eq local-abbrev-table orig-abbrev-table)))))

(ert-deftest yublin-mode-respects-enable-single-letter ()
  "When `yublin-enable-single-letter' is nil, use the no-single table."
  (with-temp-buffer
    (let ((yublin-enable-single-letter nil))
      (yublin-mode 1)
      (should (eq local-abbrev-table yublin-abbrev-table--no-single))
      (yublin-mode -1))))

(ert-deftest yublin-mode-restores-previous-table ()
  "If abbrev-mode was already on with a custom table, restore it."
  (with-temp-buffer
    (abbrev-mode 1)
    (let ((custom-table (make-abbrev-table)))
      (setq-local local-abbrev-table custom-table)
      (yublin-mode 1)
      (should (eq local-abbrev-table yublin-abbrev-table))
      (yublin-mode -1)
      (should (eq local-abbrev-table custom-table))
      (should abbrev-mode))))

(ert-deftest yublin-global-turn-on-skips-code-buffers ()
  "`yublin--turn-on' should skip `prog-mode' buffers."
  (with-temp-buffer
    (python-mode)
    (yublin--turn-on)
    (should-not yublin-mode)))

(ert-deftest yublin-mode-restores-global-abbrev ()
  "When abbrev-mode is globally on with default table, toggling yublin
should restore the original state without disabling abbrev-mode."
  (with-temp-buffer
    (abbrev-mode 1)
    (let ((orig-table local-abbrev-table))
      (yublin-mode 1)
      (should yublin-mode)
      (should abbrev-mode)
      (yublin-mode -1)
      (should-not yublin-mode)
      ;; abbrev-mode should still be on (it was on before yublin)
      (should abbrev-mode)
      ;; The original table should be back
      (should (eq local-abbrev-table orig-table)))))

(ert-deftest yublin-global-turn-on-accepts-text-buffers ()
  "`yublin--turn-on' should activate in `text-mode' buffers."
  (with-temp-buffer
    (text-mode)
    (yublin--turn-on)
    (should yublin-mode)))

(ert-deftest yublin-capf-at-shortcut ()
  "`yublin--capf' should return expansion bounds and candidates."
  (with-temp-buffer
    (yublin-mode 1)
    (insert "bc")
    (let ((result (yublin--capf)))
      (should result)
      (should (= (nth 0 result) 1))   ; start
      (should (= (nth 1 result) 3))   ; end
      (should (equal (nth 2 result) '("because"))))))

(ert-deftest yublin-capf-not-a-shortcut ()
  "`yublin--capf' should return nil for unknown words."
  (with-temp-buffer
    (yublin-mode 1)
    (insert "xyzzy")
    (should-not (yublin--capf))))

(ert-deftest yublin-capf-respects-single-letter ()
  "`yublin--capf' finds single-letter shortcuts when they are enabled."
  (with-temp-buffer
    (let ((yublin-enable-single-letter t))
      (yublin-mode 1)
      (insert "t")
      (let ((result (yublin--capf)))
        (should result)
        (should (equal (nth 2 result) '("the")))))))

(ert-deftest yublin-capf-no-single-letter-by-opt-out ()
  "`yublin--capf' does not offer single-letter completions when opted out."
  (with-temp-buffer
    (let ((yublin-enable-single-letter nil))
      (yublin-mode 1)
      (insert "t")
      (should-not (yublin--capf)))))

(ert-deftest yublin-describe-shortcut-known ()
  "`yublin-describe-shortcut' should message the expansion."
  (let ((messages nil))
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) messages))))
      (yublin-describe-shortcut "bc")
      (should (equal (car messages) "bc  →  because")))))

(ert-deftest yublin-describe-shortcut-unknown ()
  "`yublin-describe-shortcut' should report unknown shortcuts."
  (let ((messages nil))
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) messages))))
      (yublin-describe-shortcut "xyzzy")
      (should (equal (car messages) "xyzzy is not a yublin shortcut")))))

;;; Toggle / encode / decode

(ert-deftest yublin-encode-basic ()
  "Encoding should replace English words with yublin shortcuts."
  (should (equal (yublin--encode-text "I never knew what you thought about them.")
                 "I ne kw z y tt ab tm.")))

(ert-deftest yublin-decode-basic ()
  "Decoding should replace yublin shortcuts with English."
  (should (equal (yublin--decode-text "I ne kw z y tt ab tm.")
                 "I never knew what you thought about them.")))

(ert-deftest yublin-toggle-english ()
  "Toggling English text should encode it to yublin."
  (should (equal (yublin--toggle-text "I never knew what you thought about them.")
                 "I ne kw z y tt ab tm.")))

(ert-deftest yublin-toggle-yublin ()
  "Toggling yublin text should decode it to English."
  (should (equal (yublin--toggle-text "I ne kw z y tt ab tm.")
                 "I never knew what you thought about them.")))

(ert-deftest yublin-toggle-mixed-ambiguous ()
  "Toggle should handle ambiguous short text gracefully."
  ;; Short text with no clear signal — should encode (default).
  (let ((result (yublin--toggle-text "the cat")))
    (should (member result '("t cat" "the cat")))))

(ert-deftest yublin-capitalize-lower ()
  "Lowercase original preserves lowercase replacement."
  (should (equal (yublin--capitalize "the" "t") "the")))

(ert-deftest yublin-capitalize-title ()
  "Capitalized original capitalizes replacement."
  (should (equal (yublin--capitalize "the" "T") "The")))

(ert-deftest yublin-capitalize-all-caps ()
  "All-caps original upcases replacement."
  (should (equal (yublin--capitalize "the" "THE") "THE")))

(ert-deftest yublin-capitalize-title-word ()
  "Title-case original capitalizes replacement."
  (should (equal (yublin--capitalize "the" "The") "The")))

(ert-deftest yublin-decode-skip-pronoun-I ()
  "Capital I should not be decoded to His (it is the pronoun)."
  (should (equal (yublin--decode-text "I think")
                 "I think")))

(ert-deftest yublin-decode-lowercase-i ()
  "Lowercase i should still decode to his."
  (should (equal (yublin--decode-text "i think")
                 "his think")))

;;; Apostrophe safety (R2 regression tests)

(ert-deftest yublin-decode-preserves-contractions ()
  "Decoding must not split apostrophe contractions.
Literal contractions are not shortcuts (they have dedicated
letter-only shortcuts like dt/gb/ll) and must pass through unchanged."
  (dolist (text '("don't" "I'm here" "it's" "can't" "she's" "I'll"
                  "you're" "that's"))
    (should (equal (yublin--decode-text text) text))))

(ert-deftest yublin-decode-leaves-apostrophe-suffix-alone ()
  "A letter starting right after an apostrophe must not decode
(e.g. the s in DO's, or a leading 's)."
  (should (equal (yublin--decode-text "DO's") "DO's"))
  (should (equal (yublin--decode-text "'s been a long time")
                 "'s been a long time")))

(ert-deftest yublin-capitalize-preserves-contractions ()
  "Capitalizing a contraction must not treat ' as a word boundary."
  (should (equal (yublin--capitalize "he's" "Wq") "He's"))
  (should (equal (yublin--capitalize "i'll" "Ll") "I'll"))
  (should (equal (yublin--capitalize "he's" "HE'S") "HE'S")))

(ert-deftest yublin-toggle-roundtrip-with-contractions ()
  "Encode followed by decode must round-trip contractions exactly."
  (dolist (text '("I'm not going to the store."
                  "He's not here, but I'll be back."
                  "She said that's enough, don't you think?"))
    (let* ((enc (yublin--encode-text text))
           (dec (yublin--decode-text enc)))
      (should (equal dec text)))))

(ert-deftest yublin-toggle-region-sets-up-tables ()
  "Calling `yublin-toggle-region' builds the lookup tables."
  (with-temp-buffer
    (insert "the cat")
    (yublin-toggle-region (point-min) (point-max))
    (should yublin--decode-table)
    (should yublin--encode-table)
    (should (hash-table-p yublin--decode-table))))

(ert-deftest yublin--enable-sets-capf-hook ()
  "Enabling yublin-mode adds `yublin--capf' to `completion-at-point-functions'."
  (with-temp-buffer
    (yublin-mode 1)
    (should (memq #'yublin--capf completion-at-point-functions))
    (yublin-mode -1)
    (should-not (memq #'yublin--capf completion-at-point-functions))))

(ert-deftest yublin--enable-sets-abbrev-expand-function ()
  "Enabling yublin-mode sets `abbrev-expand-function' to yublin's custom one."
  (with-temp-buffer
    (yublin-mode 1)
    (should (eq abbrev-expand-function #'yublin--abbrev-expand))
    (yublin-mode -1)
    (should-not (eq abbrev-expand-function #'yublin--abbrev-expand))))

;;; Joined-word skipping

(defun yublin-test--expand-with-yublin-mode (shortcut)
  "Insert SHORTCUT in a temp buffer with `yublin-mode' enabled, then expand.
Returns the buffer contents after expansion."
  (with-temp-buffer
    (yublin-mode 1)
    (insert shortcut)
    (expand-abbrev)
    (buffer-string)))

(ert-deftest yublin-skip-file-extension-rs ()
  "File extension .rs in main.rs should NOT expand to .rest."
  (should (equal (yublin-test--expand-with-yublin-mode "main.rs")
                 "main.rs")))

(ert-deftest yublin-skip-file-extension-md ()
  "File extension .md in AGENTS.md should NOT expand to .mind."
  (should (equal (yublin-test--expand-with-yublin-mode "AGENTS.md")
                 "AGENTS.md")))

(ert-deftest yublin-skip-file-extension-sql ()
  "File extension .sql in backup.sql should NOT expand (ql -> story)."
  (should (equal (yublin-test--expand-with-yublin-mode "backup.sql")
                 "backup.sql")))

(ert-deftest yublin-skip-joined-word-respects-custom ()
  "When `yublin-skip-joined-words' is nil, joined words do expand."
  (with-temp-buffer
    (yublin-mode 1)
    (let ((yublin-skip-joined-words nil))
      (insert "main.rs")
      (expand-abbrev)
      (should (equal (buffer-string) "main.rest")))))

(ert-deftest yublin-normal-expand-still-works ()
  "Normal yublin shortcuts still expand even with file-extension check."
  (should (equal (yublin-test--expand-with-yublin-mode "bc")
                 "because"))
  (should (equal (yublin-test--expand-with-yublin-mode "gd")
                 "good")))

(ert-deftest yublin-no-false-positive-space ()
  "Word preceded by space, not dot, should still expand normally."
  (should (equal (yublin-test--expand-with-yublin-mode " bc")
                 " because")))

(ert-deftest yublin-skip-apostrophe-contraction ()
  "Apostrophe before a shortcut (DO's) should NOT expand to DO'she."
  (should (equal (yublin-test--expand-with-yublin-mode "DO's")
                 "DO's")))

(ert-deftest yublin-skip-slash-path ()
  "Slash before a shortcut (foo/rs) should NOT expand to foo/rest."
  (should (equal (yublin-test--expand-with-yublin-mode "foo/rs")
                 "foo/rs")))

(ert-deftest yublin-skip-dash-joined ()
  "Dash before a shortcut (some-rs) should NOT expand to some-rest."
  (should (equal (yublin-test--expand-with-yublin-mode "some-rs")
                 "some-rs")))

(ert-deftest yublin-skip-paren-joined ()
  "Shortcut after '(' like file(s) should NOT expand to file(she)."
  (should (equal (yublin-test--expand-with-yublin-mode "file(s")
                 "file(s")))

(ert-deftest yublin-skip-bracket-joined ()
  "Shortcut after '[' like opt[s] should NOT expand to opt[she]."
  (should (equal (yublin-test--expand-with-yublin-mode "opt[s")
                 "opt[s")))

(ert-deftest yublin-skip-brace-joined ()
  "Shortcut after '{' like val{t} should NOT expand to val{the}."
  (should (equal (yublin-test--expand-with-yublin-mode "val{t")
                 "val{t")))

(provide 'yublin-tests)
;;; yublin-tests.el ends here
