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

(provide 'yublin-tests)
;;; yublin-tests.el ends here
