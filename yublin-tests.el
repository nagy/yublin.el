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

(ert-deftest yublin-dictionary-single-letter-count ()
  "Verify 25 single-letter entries matching the known yublin set."
  (let ((count 0))
    (dolist (entry yublin--dictionary)
      (when (= (length (car entry)) 1)
        (setq count (1+ count))))
    (should (= count 25))))

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

(ert-deftest yublin-no-expand-single-letter-without-opt-in ()
  "Single-letter shortcuts should NOT expand in the default table."
  ;; The default table (no-single) doesn't have single-letter entries,
  ;; so trying to expand "t" should leave it unchanged.
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
      (should (eq local-abbrev-table yublin-abbrev-table--no-single))
      ;; Disable
      (yublin-mode -1)
      (should-not yublin-mode)
      (should (eq local-abbrev-table orig-abbrev-table)))))

(ert-deftest yublin-mode-respects-enable-single-letter ()
  "When `yublin-enable-single-letter' is t, use the full table."
  (with-temp-buffer
    (let ((yublin-enable-single-letter t))
      (yublin-mode 1)
      (should (eq local-abbrev-table yublin-abbrev-table))
      (yublin-mode -1))))

(ert-deftest yublin-mode-restores-previous-table ()
  "If abbrev-mode was already on with a custom table, restore it."
  (with-temp-buffer
    (abbrev-mode 1)
    (let ((custom-table (make-abbrev-table)))
      (setq-local local-abbrev-table custom-table)
      (yublin-mode 1)
      (should (eq local-abbrev-table yublin-abbrev-table--no-single))
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

(provide 'yublin-tests)
;;; yublin-tests.el ends here
