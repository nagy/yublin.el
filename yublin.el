;;; yublin.el --- Yublin shorthand expansion for Emacs -*- lexical-binding: t -*-

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

;; Author: Daniel Nagy
;; Version: 0.1.0
;; Keywords: convenience, abbrev, writing
;; URL: https://github.com/nagy/yublin.el
;; Package-Requires: ((emacs "28.1"))

;;; Commentary:

;; Yublin is a shorthand system for speed-writing, designed by Jon
;; Aquino.  It reduces the 600 most common English words to 1- and
;; 2-letter abbreviations ("shortcuts").
;;
;; This package implements yublin as a buffer-local minor mode built
;; on top of `abbrev-mode'.  When `yublin-mode' is enabled:
;;
;;   - Typing a shortcut followed by a word-separator (SPC,
;;     punctuation, etc.) automatically expands it to the full word.
;;
;;   - Case is handled automatically: typing "t" + SPC expands to
;;     "the", while "T" + SPC expands to "The".
;;
;;   - While you type, `abbrev-suggest' shows the expansion hint in
;;     the echo area -- you see what the shortcut will expand to
;;     before committing it.
;;
;;   - Pressing TAB on a shortcut offers the expansion via
;;     `completion-at-point', integrating with company-mode, corfu,
;;     and other completion frameworks.
;;
;;   - M-x yublin-describe-shortcut shows the expansion for any
;;     shortcut.
;;
;;   - M-x yublin-toggle-region switches a region between English
;;     and yublin, auto-detecting the direction.  Evil users can
;;     bind `evil-yublin' as an operator (e.g. "g y y" for the
;;     current line, "g y w" for the next word).
;;
;;   - Single-letter shortcuts ("t" -> "the", "n" -> "and", etc.) are
;;     enabled by default.  Set `yublin-enable-single-letter' to nil
;;     if you find them too aggressive.
;;
;; Examples (what you type → what appears):
;;
;;   y kn z I tk ab l j.        →  You know what I think about all this.
;;   s c h k p o b m.           →  She said that they were not with him.
;;   I ne kw z y tt ab tm.      →  I never knew what you thought about them.
;;
;; Usage:
;;
;;   ;; Enable manually in a buffer:
;;   M-x yublin-mode
;;
;;   ;; Enable automatically in text modes:
;;   (add-hook 'text-mode-hook #'yublin-mode)
;;
;;   ;; Or use the globalized minor mode:
;;   (yublin-global-mode 1)
;;
;; For more information about the yublin shorthand system, see:
;; https://www.jona.ca/2007/06/yublin-shorthand-for-speed-writing.html

;;; Code:

(require 'abbrev)

(defgroup yublin nil
  "Yublin shorthand expansion for speed-writing."
  :group 'convenience
  :prefix "yublin-")

(defcustom yublin-enable-single-letter t
  "When non-nil, enable single-letter shortcuts.
Single-letter shortcuts (e.g. \"t\" -> \"the\", \"n\" -> \"and\")
are very aggressive and can interfere with normal typing.  Set
this to nil if you find them too intrusive."
  :type 'boolean
  :group 'yublin)

(defcustom yublin-abbrev-suggest t
  "When non-nil, show the expansion hint in the echo area.
Uses `abbrev-suggest' to display a preview of what the
yublin shortcut under point expands to, before you commit it
with a space or punctuation key.

Requires Emacs 28.1 or later."
  :type 'boolean
  :group 'yublin)

(defcustom yublin-skip-joined-words t
  "When non-nil, don't expand abbrevs that are part of a larger token.
This prevents expansions like \='rs\=' → \='rest\=' in filenames such as
\='main.rs\=', or \='s\=' → \='she\=' in contractions like \='DO's\='.

It works by checking whether the shortcut is immediately preceded
by a connector character (period, apostrophe, slash, dash, or
backslash) — the kind of thing that joins the shortcut to a
larger word or path."
  :type 'boolean
  :group 'yublin)


;;; Dictionary

;; The full yublin shorthand dictionary.
;; Generated from Jon Aquino's yublin cheatsheet (600 most common
;; English words reduced to 1- and 2-letter shortcuts).

(defconst yublin--dictionary
  '(("aa" . "against")
    ("ab" . "about")
    ("ac" . "account")
    ("ad" . "asked")
    ("ae" . "manner")
    ("af" . "after")
    ("ag" . "again")
    ("ai" . "making")
    ("aj" . "seen")
    ("ak" . "taken")
    ("al" . "always")
    ("ao" . "almost")
    ("ap" . "appeared")
    ("ar" . "another")
    ("au" . "daughter")
    ("av" . "leave")
    ("aw" . "away")
    ("ay" . "anything")
    ("az" . "half")
    ("b" . "with")
    ("ba" . "back")
    ("bb" . "among")
    ("bc" . "because")
    ("bd" . "behind")
    ("bf" . "before")
    ("bg" . "being")
    ("bh" . "brother")
    ("bi" . "business")
    ("bj" . "less")
    ("bk" . "black")
    ("bl" . "believe")
    ("bm" . "became")
    ("bn" . "been")
    ("bo" . "both")
    ("bp" . "master")
    ("bq" . "mean")
    ("br" . "better")
    ("bs" . "best")
    ("bt" . "between")
    ("bu" . "brought")
    ("bv" . "above")
    ("bx" . "matter")
    ("bz" . "used")
    ("c" . "said")
    ("ca" . "came")
    ("cb" . "sort")
    ("cc" . "character")
    ("cd" . "called")
    ("ce" . "come")
    ("cf" . "comfort")
    ("cg" . "coming")
    ("ch" . "child")
    ("ci" . "children")
    ("cj" . "care")
    ("cl" . "call")
    ("cm" . "company")
    ("cn" . "certain")
    ("co" . "could")
    ("cp" . "chapter")
    ("cq" . "standing")
    ("cr" . "cried")
    ("cs" . "close")
    ("ct" . "cannot")
    ("cu" . "course")
    ("cv" . "conversation")
    ("cw" . "short")
    ("cx" . "others")
    ("cy" . "country")
    ("cz" . "it's")
    ("d" . "had")
    ("da" . "days")
    ("db" . "that's")
    ("dc" . "doctor")
    ("dd" . "added")
    ("de" . "dear")
    ("dg" . "doing")
    ("dh" . "death")
    ("di" . "different")
    ("dj" . "read")
    ("dk" . "dark")
    ("dl" . "deal")
    ("dn" . "down")
    ("dp" . "deep")
    ("dq" . "already")
    ("dr" . "door")
    ("ds" . "does")
    ("dt" . "don't")
    ("du" . "doubt")
    ("dw" . "drew")
    ("dx" . "either")
    ("dy" . "ready")
    ("dz" . "means")
    ("e" . "her")
    ("ea" . "began")
    ("eb" . "everybody")
    ("ec" . "each")
    ("ed" . "heard")
    ("ee" . "three")
    ("ef" . "herself")
    ("eh" . "enough")
    ("ei" . "evening")
    ("ej" . "talk")
    ("ek" . "week")
    ("el" . "else")
    ("em" . "seems")
    ("en" . "even")
    ("eo" . "second")
    ("ep" . "help")
    ("eq" . "hard")
    ("er" . "hear")
    ("es" . "eyes")
    ("et" . "letter")
    ("eu" . "creature")
    ("ev" . "ever")
    ("ew" . "afterwards")
    ("ex" . "except")
    ("ey" . "every")
    ("ez" . "turn")
    ("f" . "for")
    ("fa" . "face")
    ("fb" . "thus")
    ("fc" . "fact")
    ("fd" . "friend")
    ("fe" . "felt")
    ("ff" . "effect")
    ("fg" . "feeling")
    ("fh" . "further")
    ("fi" . "first")
    ("fj" . "along")
    ("fl" . "feel")
    ("fm" . "form")
    ("fn" . "find")
    ("fo" . "found")
    ("fp" . "glad")
    ("fq" . "sense")
    ("fr" . "father")
    ("fs" . "friends")
    ("ft" . "often")
    ("fu" . "full")
    ("fv" . "five")
    ("fw" . "fellow")
    ("fy" . "family")
    ("fz" . "white")
    ("g" . "which")
    ("ga" . "gave")
    ("gb" . "can't")
    ("gc" . "wanted")
    ("gd" . "good")
    ("ge" . "gone")
    ("gf" . "mine")
    ("gg" . "going")
    ("gh" . "high")
    ("gi" . "give")
    ("gj" . "fell")
    ("gk" . "bear")
    ("gl" . "girl")
    ("gm" . "gentlemen")
    ("gn" . "gentleman")
    ("gp" . "fear")
    ("gq" . "state")
    ("gr" . "great")
    ("gs" . "thoughts")
    ("gt" . "sight")
    ("gu" . "ground")
    ("gv" . "given")
    ("gw" . "grew")
    ("gx" . "also")
    ("gy" . "angry")
    ("gz" . "fine")
    ("h" . "that")
    ("ha" . "hand")
    ("hb" . "husband")
    ("hc" . "church")
    ("hd" . "head")
    ("hf" . "himself")
    ("hg" . "having")
    ("hh" . "whether")
    ("hj" . "case")
    ("hk" . "thinking")
    ("hl" . "while")
    ("hn" . "thing")
    ("ho" . "house")
    ("hp" . "hope")
    ("hq" . "held")
    ("hr" . "here")
    ("hs" . "those")
    ("ht" . "heart")
    ("hu" . "hour")
    ("hv" . "heavy")
    ("hw" . "however")
    ("hx" . "walk")
    ("hy" . "happy")
    ("hz" . "lost")
    ("i" . "his")
    ("ia" . "idea")
    ("ic" . "silence")
    ("id" . "indeed")
    ("ig" . "things")
    ("ih" . "wish")
    ("ii" . "within")
    ("ij" . "water")
    ("ik" . "likely")
    ("il" . "till")
    ("im" . "times")
    ("io" . "into")
    ("ip" . "impossible")
    ("iq" . "hold")
    ("ir" . "fire")
    ("iu" . "minutes")
    ("iv" . "live")
    ("iw" . "afraid")
    ("ix" . "bring")
    ("iy" . "immediately")
    ("iz" . "honour")
    ("j" . "this")
    ("ja" . "seeing")
    ("jb" . "dead")
    ("jc" . "able")
    ("jd" . "arms")
    ("jf" . "late")
    ("jg" . "opinion")
    ("jh" . "four")
    ("ji" . "none")
    ("jj" . "hair")
    ("jk" . "sister")
    ("jl" . "entered")
    ("jm" . "sent")
    ("jn" . "married")
    ("jp" . "longer")
    ("jq" . "women")
    ("jr" . "hours")
    ("js" . "horse")
    ("jt" . "wonder")
    ("ju" . "just")
    ("jv" . "cold")
    ("jw" . "please")
    ("jx" . "fair")
    ("jy" . "lord")
    ("jz" . "stay")
    ("k" . "they")
    ("ka" . "interest")
    ("kb" . "won't")
    ("kd" . "walked")
    ("ke" . "keep")
    ("kg" . "taking")
    ("kh" . "opened")
    ("ki" . "kind")
    ("kj" . "change")
    ("kk" . "laid")
    ("kl" . "knowledge")
    ("km" . "strange")
    ("kn" . "know")
    ("ko" . "known")
    ("kq" . "feet")
    ("kr" . "tears")
    ("ks" . "knows")
    ("kt" . "kept")
    ("ku" . "body")
    ("kv" . "past")
    ("kw" . "knew")
    ("kx" . "order")
    ("ky" . "need")
    ("kz" . "pleased")
    ("l" . "all")
    ("la" . "last")
    ("lb" . "dinner")
    ("ld" . "looked")
    ("le" . "like")
    ("lf" . "life")
    ("lg" . "looking")
    ("lh" . "light")
    ("li" . "little")
    ("lj" . "happened")
    ("lk" . "look")
    ("ll" . "I'll")
    ("lm" . "sitting")
    ("ln" . "alone")
    ("lo" . "long")
    ("lp" . "lips")
    ("lq" . "getting")
    ("lr" . "large")
    ("ls" . "least")
    ("lt" . "left")
    ("lu" . "laughed")
    ("lv" . "love")
    ("lw" . "followed")
    ("lx" . "there's")
    ("ly" . "lady")
    ("lz" . "besides")
    ("m" . "him")
    ("ma" . "made")
    ("mc" . "soul")
    ("md" . "mind")
    ("mf" . "myself")
    ("mg" . "morning")
    ("mh" . "mother")
    ("mi" . "might")
    ("mj" . "early")
    ("mk" . "make")
    ("ml" . "smile")
    ("mm" . "moment")
    ("mn" . "many")
    ("mo" . "more")
    ("mq" . "rose")
    ("ms" . "most")
    ("mt" . "must")
    ("mu" . "much")
    ("mv" . "moved")
    ("mx" . "aunt")
    ("mz" . "hundred")
    ("n" . "and")
    ("na" . "name")
    ("nb" . "nobody")
    ("nc" . "necessary")
    ("nd" . "answered")
    ("ne" . "never")
    ("ng" . "nothing")
    ("nh" . "neither")
    ("ni" . "night")
    ("nj" . "across")
    ("nk" . "thank")
    ("nl" . "general")
    ("nm" . "handsome")
    ("nn" . "continued")
    ("np" . "carried")
    ("nq" . "worse")
    ("nr" . "near")
    ("ns" . "hands")
    ("nt" . "next")
    ("nu" . "nature")
    ("nw" . "answer")
    ("nx" . "chair")
    ("ny" . "money")
    ("nz" . "tone")
    ("o" . "not")
    ("oa" . "road")
    ("ob" . "observed")
    ("oc" . "once")
    ("od" . "stood")
    ("oe" . "done")
    ("og" . "together")
    ("oi" . "sometimes")
    ("oj" . "object")
    ("ol" . "whole")
    ("om" . "home")
    ("oo" . "took")
    ("op" . "open")
    ("oq" . "standing")
    ("os" . "whose")
    ("ot" . "other")
    ("ou" . "ought")
    ("ov" . "over")
    ("ow" . "town")
    ("ox" . "sorry")
    ("oy" . "only")
    ("oz" . "stand")
    ("p" . "were")
    ("pa" . "part")
    ("pb" . "probably")
    ("pc" . "appearance")
    ("pd" . "passed")
    ("pe" . "perhaps")
    ("pf" . "perfectly")
    ("pg" . "speaking")
    ("pi" . "possible")
    ("pj" . "meet")
    ("pl" . "place")
    ("pm" . "promise")
    ("pn" . "person")
    ("po" . "poor")
    ("pp" . "people")
    ("pq" . "instead")
    ("pr" . "present")
    ("ps" . "pleasure")
    ("pt" . "point")
    ("pu" . "purpose")
    ("pw" . "power")
    ("px" . "wished")
    ("py" . "pretty")
    ("pz" . "sound")
    ("q" . "would")
    ("qa" . "silent")
    ("qb" . "common")
    ("qc" . "meant")
    ("qd" . "tried")
    ("qe" . "until")
    ("qf" . "mouth")
    ("qg" . "occasion")
    ("qh" . "marry")
    ("qj" . "length")
    ("ql" . "story")
    ("qm" . "street")
    ("qn" . "question")
    ("qo" . "remained")
    ("qp" . "become")
    ("qq" . "loved")
    ("qs" . "seem")
    ("qt" . "quiet")
    ("qu" . "quite")
    ("qv" . "ladies")
    ("qw" . "marriage")
    ("qx" . "book")
    ("qz" . "I've")
    ("r" . "from")
    ("ra" . "rather")
    ("rb" . "trouble")
    ("rc" . "received")
    ("rd" . "round")
    ("rg" . "strong")
    ("rh" . "truth")
    ("ri" . "right")
    ("rj" . "obliged")
    ("rk" . "struck")
    ("rl" . "hardly")
    ("rm" . "remember")
    ("rn" . "reason")
    ("ro" . "room")
    ("rp" . "replied")
    ("rq" . "particular")
    ("rr" . "return")
    ("rs" . "rest")
    ("rt" . "returned")
    ("ru" . "true")
    ("rv" . "resolved")
    ("rw" . "forward")
    ("rx" . "pass")
    ("ry" . "really")
    ("rz" . "knowing")
    ("s" . "she")
    ("sa" . "same")
    ("sb" . "subject")
    ("sc" . "since")
    ("sd" . "seemed")
    ("se" . "some")
    ("sf" . "itself")
    ("sg" . "something")
    ("sh" . "should")
    ("si" . "side")
    ("sj" . "former")
    ("sk" . "spoke")
    ("sl" . "shall")
    ("sm" . "small")
    ("sn" . "soon")
    ("sp" . "speak")
    ("sq" . "blood")
    ("sr" . "sure")
    ("ss" . "miss")
    ("st" . "still")
    ("su" . "such")
    ("sv" . "several")
    ("sw" . "show")
    ("sx" . "sake")
    ("sy" . "says")
    ("sz" . "fortune")
    ("t" . "the")
    ("ta" . "take")
    ("tb" . "table")
    ("tc" . "distance")
    ("td" . "told")
    ("te" . "then")
    ("tf" . "therefore")
    ("tg" . "through")
    ("th" . "there")
    ("ti" . "time")
    ("tj" . "presence")
    ("tk" . "think")
    ("tl" . "tell")
    ("tm" . "them")
    ("tn" . "than")
    ("tp" . "stopped")
    ("tq" . "feelings")
    ("tr" . "their")
    ("ts" . "these")
    ("tt" . "thought")
    ("tu" . "though")
    ("tv" . "themselves")
    ("tw" . "towards")
    ("tx" . "corner")
    ("ty" . "certainly")
    ("tz" . "talking")
    ("u" . "but")
    ("ua" . "natural")
    ("uc" . "circumstances")
    ("ud" . "turned")
    ("ue" . "suppose")
    ("uf" . "beautiful")
    ("ug" . "turning")
    ("ui" . "during")
    ("uj" . "spirit")
    ("uk" . "foot")
    ("ul" . "usual")
    ("un" . "upon")
    ("uo" . "supposed")
    ("uq" . "wind")
    ("ur" . "under")
    ("ut" . "understand")
    ("uv" . "presently")
    ("uw" . "comes")
    ("ux" . "attention")
    ("uy" . "suddenly")
    ("uz" . "wait")
    ("v" . "have")
    ("vb" . "play")
    ("vc" . "service")
    ("vd" . "lived")
    ("ve" . "very")
    ("vf" . "easy")
    ("vg" . "everything")
    ("vh" . "real")
    ("vi" . "living")
    ("vj" . "clear")
    ("vk" . "worth")
    ("vm" . "cause")
    ("vn" . "giving")
    ("vo" . "voice")
    ("vp" . "send")
    ("vq" . "spirits")
    ("vt" . "visit")
    ("vu" . "chance")
    ("vv" . "didn't")
    ("vw" . "view")
    ("vx" . "pleasant")
    ("vy" . "party")
    ("vz" . "beginning")
    ("w" . "was")
    ("wa" . "want")
    ("wb" . "horses")
    ("wd" . "world")
    ("wf" . "wife")
    ("wg" . "wrong")
    ("wh" . "where")
    ("wi" . "will")
    ("wj" . "notice")
    ("wk" . "work")
    ("wl" . "well")
    ("wm" . "whom")
    ("wn" . "went")
    ("wo" . "woman")
    ("wp" . "duty")
    ("wq" . "he's")
    ("wr" . "word")
    ("ws" . "words")
    ("wt" . "without")
    ("wv" . "whatever")
    ("ww" . "window")
    ("wx" . "figure")
    ("wy" . "twenty")
    ("wz" . "leaving")
    ("x" . "when")
    ("xa" . "sleep")
    ("xb" . "entirely")
    ("xc" . "exclaimed")
    ("xd" . "expected")
    ("xe" . "fall")
    ("xf" . "months")
    ("xg" . "broken")
    ("xh" . "secret")
    ("xi" . "thousand")
    ("xj" . "happiness")
    ("xk" . "minute")
    ("xl" . "human")
    ("xm" . "fancy")
    ("xo" . "strength")
    ("xp" . "showed")
    ("xq" . "pounds")
    ("xr" . "nearly")
    ("xs" . "captain")
    ("xt" . "expect")
    ("xu" . "piece")
    ("xv" . "school")
    ("xw" . "write")
    ("xx" . "reached")
    ("xy" . "exactly")
    ("xz" . "repeated")
    ("y" . "you")
    ("ya" . "walking")
    ("yb" . "father's")
    ("yc" . "heaven")
    ("yd" . "beyond")
    ("ye" . "years")
    ("yf" . "yourself")
    ("yg" . "young")
    ("yi" . "saying")
    ("yj" . "beauty")
    ("yk" . "shook")
    ("ym" . "waiting")
    ("yo" . "your")
    ("yp" . "desire")
    ("yq" . "news")
    ("yr" . "year")
    ("yt" . "front")
    ("yv" . "laugh")
    ("yw" . "uncle")
    ("yx" . "miles")
    ("yz" . "caught")
    ("z" . "what")
    ("za" . "regard")
    ("zb" . "easily")
    ("zc" . "glass")
    ("zd" . "consider")
    ("ze" . "green")
    ("zf" . "considered")
    ("zg" . "unless")
    ("zh" . "stop")
    ("zi" . "forth")
    ("zj" . "altogether")
    ("zk" . "surprise")
    ("zl" . "sudden")
    ("zm" . "free")
    ("zn" . "grave")
    ("zo" . "carriage")
    ("zp" . "believed")
    ("zq" . "putting")
    ("zr" . "carry")
    ("zs" . "mentioned")
    ("zt" . "looks")
    ("zu" . "scarcely")
    ("zv" . "society")
    ("zw" . "affection")
    ("zx" . "dress")
    ("zy" . "earth"))
  "The full yublin shorthand dictionary.
Each element is (SHORTCUT . EXPANSION) where SHORTCUT is a 1- or
2-letter string and EXPANSION is the full English word.")

(defun yublin--build-abbrev-table (include-single-letter)
  "Build an abbrev table from `yublin--dictionary'.
If INCLUDE-SINGLE-LETTER is nil, omit 1-letter shortcuts."
  (let ((table (make-abbrev-table)))
    (dolist (entry yublin--dictionary)
      (let ((shortcut (car entry))
            (expansion (cdr entry)))
        (when (or include-single-letter
                  (> (length shortcut) 1))
          (define-abbrev table shortcut expansion nil
            :case-fixed t :system t))))
    table))

;; Pre-built tables for performance: switching is instantaneous.
(defvar yublin-abbrev-table
  (yublin--build-abbrev-table t)
  "Abbrev table containing all yublin shortcuts, including single-letter.")

(defvar yublin-abbrev-table--no-single
  (yublin--build-abbrev-table nil)
  "Abbrev table containing only the 2-letter yublin shortcuts.")

(defun yublin--active-abbrev-table ()
  "Return the abbrev table to use based on `yublin-enable-single-letter'."
  (if yublin-enable-single-letter
      yublin-abbrev-table
    yublin-abbrev-table--no-single))


;;; Minor mode

(defvar-local yublin--previous-abbrev-table nil
  "The buffer's `local-abbrev-table' before `yublin-mode' was enabled.
Used to restore the original table when the mode is disabled.")

(defvar-local yublin--was-abbrev-mode nil
  "Non-nil if `abbrev-mode' was enabled before `yublin-mode'.")

(defun yublin--enable ()
  "Activate yublin abbrev table in the current buffer."
  (setq yublin--previous-abbrev-table local-abbrev-table
        yublin--was-abbrev-mode abbrev-mode)
  (setq-local local-abbrev-table (yublin--active-abbrev-table))
  (abbrev-mode 1)
  ;; Echo-area hint while typing
  (when (and yublin-abbrev-suggest (boundp 'abbrev-suggest))
    (setq-local abbrev-suggest t
                abbrev-suggest-hint-threshold 0))
  ;; Custom expand function to skip file extensions
  (setq-local abbrev-expand-function #'yublin--abbrev-expand)
  ;; TAB / company / corfu integration
  (add-hook 'completion-at-point-functions #'yublin--capf 0 t))

(defun yublin--disable ()
  "Deactivate yublin abbrev table in the current buffer."
  (when (eq local-abbrev-table (yublin--active-abbrev-table))
    (if yublin--previous-abbrev-table
        (setq-local local-abbrev-table yublin--previous-abbrev-table)
      (kill-local-variable 'local-abbrev-table)))
  (unless yublin--was-abbrev-mode
    (abbrev-mode -1))
  (kill-local-variable 'abbrev-expand-function)
  (remove-hook 'completion-at-point-functions #'yublin--capf t))

;;;###autoload
(define-minor-mode yublin-mode
  "Toggle yublin shorthand expansion in the current buffer.

When enabled, typing a yublin shortcut followed by a space or
punctuation character expands it to the corresponding English
word.  For example, typing \"bc\" followed by SPC expands to
\"because\".

While typing, `abbrev-suggest' shows a hint in the echo area so
you can preview the expansion before committing it with a space
or punctuation key.  Pressing TAB on a shortcut also offers the
expansion via `completion-at-point', which integrates with
company-mode, corfu, and other completion frameworks.

Single-letter shortcuts (e.g. \"t\" -> \"the\", \"n\" -> \"and\")
are enabled by default.  Set `yublin-enable-single-letter' to nil
if you find them too aggressive.

Yublin mode uses `abbrev-mode' internally.  The mode replaces the
buffer's local abbrev table with the yublin dictionary.  Turning
off `yublin-mode' restores the original abbrev table.

The yublin shorthand system was designed by Jon Aquino.
See URL `https://www.jona.ca/2007/06/yublin-shorthand-for-speed-writing.html'."
  :lighter " Ybn"
  (if yublin-mode
      (yublin--enable)
    (yublin--disable)))

;;;###autoload
(defun yublin-describe-shortcut (shortcut)
  "Display the yublin expansion for SHORTCUT.
When called interactively, prompts for a shortcut string.
If the shortcut is unknown, reports that."
  (interactive "sYublin shortcut: ")
  (let* ((table (if (and (boundp 'yublin-mode) yublin-mode)
                    (yublin--active-abbrev-table)
                  yublin-abbrev-table))
         (sym (intern-soft shortcut table)))
    (if sym
        (message "%s  →  %s" shortcut (symbol-value sym))
      (message "%s is not a yublin shortcut" shortcut))))

(defun yublin--capf ()
  "Completion-at-point function for yublin abbreviations.
When point is at the end of a yublin shortcut, offer its
expansion as a completion candidate."
  (when yublin-mode
    (when-let* ((bounds (bounds-of-thing-at-point 'word))
                (word (buffer-substring-no-properties
                       (car bounds) (cdr bounds)))
                ((> (length word) 0))
                (table (yublin--active-abbrev-table))
                (sym (intern-soft word table)))
      (list (car bounds)
            (cdr bounds)
            (list (symbol-value sym))
            :exclusive 'no
            :annotation-function (lambda (_) " (yublin)")
            :company-kind (lambda (_) 'abbrev)))))

;;;###autoload
(define-globalized-minor-mode yublin-global-mode
  yublin-mode
  yublin--turn-on
  :group 'yublin)

(defun yublin--turn-on ()
  "Turn on `yublin-mode' in the current buffer.
This is the default `turn-on' function for `yublin-global-mode'.
It skips buffers whose major mode derives from `prog-mode' or
`comint-mode' to avoid interfering with code and shell buffers."
  (unless (or (derived-mode-p 'prog-mode)
              (derived-mode-p 'comint-mode)
              (derived-mode-p 'eshell-mode)
              (derived-mode-p 'term-mode)
              (minibufferp))
    (yublin-mode 1)))


;;; Joined-word aware expansion

(defun yublin--joined-word-context-p ()
  "Return non-nil if the word before point is part of a larger token.
This detects patterns like .rs in main.rs, 's in DO's, or /rs in a
path, preventing yublin from expanding abbreviations that are joined
to a preceding word by a connector character."
  (save-excursion
    (when (/= 0 (skip-syntax-backward "w"))
      (memq (char-before) '(?. ?\x27 ?/ ?- ?\\)))))

(defun yublin--abbrev-expand ()
  "Expand yublin abbrev unless it looks like a file extension.
Calls `abbrev--default-expand' to perform the actual expansion."
  (if (and yublin-skip-joined-words
           (yublin--joined-word-context-p))
      ;; Return non-nil to tell `expand-abbrev' we handled it
      ;; (prevents `abbrev--suggest-maybe-suggest' from firing).
      t
    (abbrev--default-expand)))


;;; Toggle region (English ↔ yublin)

(defvar yublin--decode-table nil
  "Hash table mapping yublin shortcuts to their English expansions.
Built from `yublin--dictionary' on first use.")

(defvar yublin--encode-table nil
  "Hash table mapping lowercase English words to yublin shortcuts.
Built from `yublin--dictionary' on first use.")

(defun yublin--ensure-toggle-tables ()
  "Build `yublin--decode-table' and `yublin--encode-table' if needed."
  (unless yublin--decode-table
    (setq yublin--decode-table (make-hash-table :test 'equal)
          yublin--encode-table (make-hash-table :test 'equal))
    (dolist (entry yublin--dictionary)
      (let ((shortcut (car entry))
            (expansion (cdr entry)))
        (puthash shortcut expansion yublin--decode-table)
        (puthash (downcase expansion) shortcut yublin--encode-table)))))

(defun yublin-toggle-region (beg end)
  "Toggle text between BEG and END between English and yublin.

If the region appears to be yublin-encoded (dominated by 1-2
letter words matching known shortcuts), decode it to English.
Otherwise, encode English words to yublin shortcuts.

Words for which no mapping exists are left unchanged."
  (interactive "r")
  (yublin--ensure-toggle-tables)
  (let* ((text (buffer-substring-no-properties beg end))
         (result (yublin--toggle-text text)))
    (delete-region beg end)
    (insert result)))

(defun yublin--toggle-text (text)
  "Return TEXT toggled between English and yublin."
  (let ((decode-cnt 0)
        (encode-cnt 0))
    ;; Count words matching each direction to determine orientation.
    (dolist (word (split-string text nil t))
      (let ((lc (downcase word)))
        (when (gethash lc yublin--decode-table)
          (setq decode-cnt (1+ decode-cnt)))
        (when (gethash lc yublin--encode-table)
          (setq encode-cnt (1+ encode-cnt)))))
    (if (> decode-cnt encode-cnt)
        (yublin--decode-text text)
      (yublin--encode-text text))))

(defun yublin--decode-text (text)
  "Convert yublin shortcuts in TEXT to their English expansions.
Preserves capitalization: \"T\" -> \"The\", \"t\" -> \"the\"."
  (yublin--ensure-toggle-tables)
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (while (re-search-forward "\\b[[:alpha:]]+\\b" nil t)
      (let* ((word (match-string 0))
             (lc (downcase word))
             (expansion (gethash lc yublin--decode-table)))
        (when (and expansion
                   (not (yublin--skip-decode-p word expansion)))
          (replace-match (yublin--capitalize expansion word)
                         t t))))
    (buffer-string)))

(defun yublin--skip-decode-p (word expansion)
  "Return non-nil if WORD should not be decoded to EXPANSION.
This prevents a capital pronoun like \"I\" from being decoded to
\"His\" (the yublin shortcut \"i\" maps to \"his\", but a standalone
capital \"I\" is the English pronoun, not a yublin shortcut)."
  (and (= (length word) 1)
       (>= (aref word 0) ?A)
       (<= (aref word 0) ?Z)
       (/= (upcase (aref word 0))
           (upcase (aref expansion 0)))))

(defun yublin--encode-text (text)
  "Convert English words in TEXT to their yublin shortcuts.
Preserves capitalization: \"The\" -> \"T\", \"the\" -> \"t\"."
  (yublin--ensure-toggle-tables)
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (while (re-search-forward "\\b[[:alpha:]'\x27]+\\b" nil t)
      (let* ((word (match-string 0))
             (lc (downcase word))
             (shortcut (gethash lc yublin--encode-table)))
        (when shortcut
          (replace-match (yublin--capitalize shortcut (match-string 0))
                         t t))))
    (buffer-string)))

(defun yublin--capitalize (replacement original)
  "Return REPLACEMENT with the capitalization of ORIGINAL.
If ORIGINAL is all-uppercase, REPLACEMENT is upcased.
If ORIGINAL is capitalized, REPLACEMENT is capitalized.
Otherwise REPLACEMENT is returned as-is."
  (let ((case-fold-search nil)
        (first (aref original 0)))
    (cond
     ((and (> (length original) 1)
           (null (string-match-p "[[:lower:]]" original)))
      (upcase replacement))
     ((and (>= first ?A) (<= first ?Z))
      (capitalize replacement))
     (t replacement))))


;;; Evil integration (optional)

(eval-after-load 'evil
  `(evil-define-operator evil-yublin (beg end _type)
     "Toggle text between English and yublin.
See `yublin-toggle-region'."
     :move-point nil
     (interactive ,(string 60 ?r 62))
     (yublin-toggle-region beg end)))

(provide 'yublin)
;;; yublin.el ends here
