;; switch-case.scm — text case conversion commands for Helix.
;;
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; Copyright (C) 2026 Tom Waddington
;;
;; Convert the text under each selection between UPPERCASE, lowercase,
;; aLTERNATE cASE, PascalCase, camelCase, Title Case, Sentence case, snake_case
;; and kebab-case.
;;
;; Word boundaries are inferred from non-alphanumeric separators and from
;; lowercase-to-uppercase ("camel") transitions, so any input style converts to
;; any other.
;;
;; UPPERCASE, lowercase, aLTERNATE cASE, Title Case and Sentence case preserve
;; the text's punctuation, spacing and newlines, changing only letter case.
;; PascalCase, camelCase, snake_case and kebab-case re-tokenise the words: they
;; drop punctuation and leading whitespace and join the words with their
;; separator. Newlines survive every style: each line is converted on its own.

(require-builtin helix/core/text as text.)
(require "helix/editor.scm") ; editor-focus, editor->doc-id, editor->text
(require "helix/static.scm") ; selection / range primitives

(provide
  switch-to-uppercase
  switch-to-lowercase
  switch-to-alternate-case
  switch-to-pascal-case
  switch-to-camel-case
  switch-to-title-case
  switch-to-sentence-case
  switch-to-snake-case
  switch-to-kebab-case)

;;;; ---------------------------------------------------------------------------
;;;; Character classification
;;;;
;;;; Steel only exposes char-upcase / char-downcase / char-digit?, so the
;;;; case predicates are derived: a character is upper-case if down-casing it
;;;; changes it, and lower-case if up-casing it changes it.
;;;; ---------------------------------------------------------------------------

(define (char-upper? c) (not (char=? c (char-downcase c))))
(define (char-lower? c) (not (char=? c (char-upcase c))))
(define (alphanumeric? c) (or (char-digit? c) (char-upper? c) (char-lower? c)))

;; A camelCase boundary: an upper-case char immediately after a lower-case one,
;; e.g. the 'W' in "helloWorld".
(define (camel-transition? prev current)
  (and prev (char-upper? current) (char-lower? prev)))

(define (drop-leading-whitespace chars)
  (cond
    [(null? chars) '()]
    [(char-whitespace? (car chars)) (drop-leading-whitespace (cdr chars))]
    [else chars]))

;;;; ---------------------------------------------------------------------------
;;;; Case converters (string -> string)
;;;; ---------------------------------------------------------------------------

(define (to-uppercase s) (string-upcase s))
(define (to-lowercase s) (string-downcase s))

;; Flip the case of every cased character, leaving the rest untouched.
(define (to-alternate-case s)
  (list->string
    (map (lambda (c)
          (cond
            [(char-lower? c) (char-upcase c)]
            [(char-upper? c) (char-downcase c)]
            [else c]))
      (string->list s))))

;; Split `s` into its newline-separated lines, keeping empty lines so that
;; joining the pieces back with #\newline reproduces the line structure exactly.
(define (split-newlines s)
  (let loop ([cs (string->list s)] [cur '()] [segs '()])
    (cond
      [(null? cs) (reverse (cons (list->string (reverse cur)) segs))]
      [(char=? (car cs) #\newline)
        (loop (cdr cs) '() (cons (list->string (reverse cur)) segs))]
      [else (loop (cdr cs) (cons (car cs) cur) segs)])))

(define (join-newlines parts)
  (cond
    [(null? parts) ""]
    [(null? (cdr parts)) (car parts)]
    [else (string-append (car parts) "\n" (join-newlines (cdr parts)))]))

;; Lift a single-line converter to act on each line independently, so the
;; re-tokenising styles never swallow newlines.
(define (per-line convert)
  (lambda (s) (join-newlines (map convert (split-newlines s)))))

;; Structure-preserving recase for Title Case and Sentence case. Walks the
;; original string, changing only the case of alphanumeric characters and
;; emitting every other character (punctuation, whitespace, newlines) verbatim.
;;
;; `capitalize` selects which word-initial letters are upper-cased:
;;   'all   -> every word                 (Title Case)
;;   'first -> only the first word's start (Sentence case)
(define (recase s capitalize)
  (let loop ([cs (string->list s)] [prev #f] [seen-word #f] [out '()])
    (cond
      [(null? cs) (list->string (reverse out))]
      [else
        (let ([current (car cs)])
          (cond
            [(not (alphanumeric? current))
              (loop (cdr cs) current seen-word (cons current out))]
            [else
              (let* ([word-start (or (not (and prev (alphanumeric? prev)))
                                  (camel-transition? prev current))]
                     [cap (and word-start
                           (or (eq? capitalize 'all) (not seen-word)))])
                (loop (cdr cs) current #t
                  (cons (if cap (char-upcase current) (char-downcase current))
                    out)))]))])))

;; Shared driver for snake_case and kebab-case: lower-case every word and join
;; the words with `sep`. Runs of separators collapse to a single `sep`,
;; punctuation is dropped and leading whitespace is dropped.
(define (convert-with-separator s sep)
  (let loop ([cs (drop-leading-whitespace (string->list s))]
             [prev #f]
             [out '()]) ; result chars, reversed
    (cond
      [(null? cs) (list->string (reverse out))]
      [else
        (let ([current (car cs)])
          (cond
            [(not (alphanumeric? current)) (loop (cdr cs) current out)]
            [else
              ;; insert a separator at a word start that followed a separator
              ;; (but not at the very beginning) or at a camelCase boundary
              (let* ([sep-boundary (and (not (and prev (alphanumeric? prev)))
                                    (not (null? out)))]
                     [out (if (or (camel-transition? prev current) sep-boundary)
                           (cons sep out)
                           out)]
                     [out (cons (char-downcase current) out)])
                (loop (cdr cs) current out))]))])))

;; Shared driver for the butted capitalising styles (PascalCase, camelCase).
;; Words are concatenated directly; punctuation and other separators are
;; dropped and leading whitespace is dropped. Word starts come from separators
;; and camelCase transitions.
;;
;; `capitalize` selects which words get an upper-case first letter:
;;   'all           -> every word        (PascalCase)
;;   'all-but-first -> all but the first (camelCase)
(define (convert-with-capitalization s capitalize)
  (let loop ([cs (drop-leading-whitespace (string->list s))]
             [should-cap (not (eq? capitalize 'all-but-first))]
             [prev #f]
             [out '()])
    (cond
      [(null? cs) (list->string (reverse out))]
      [else
        (let ([current (car cs)])
          (cond
            ;; a separator forces the next word to be capitalised
            [(not (alphanumeric? current)) (loop (cdr cs) #t current out)]
            [else
              (let ([cap (if (camel-transition? prev current) #t should-cap)])
                (loop (cdr cs)
                  #f ; an alphanumeric char is never followed by a forced cap
                  current
                  (cons (if cap (char-upcase current) (char-downcase current))
                    out)))]))])))

(define (to-title-case s) (recase s 'all))
(define (to-sentence-case s) (recase s 'first))
(define to-pascal-case
  (per-line (lambda (s) (convert-with-capitalization s 'all))))
(define to-camel-case
  (per-line (lambda (s) (convert-with-capitalization s 'all-but-first))))
(define to-snake-case (per-line (lambda (s) (convert-with-separator s #\_))))
(define to-kebab-case (per-line (lambda (s) (convert-with-separator s #\-))))

;;;; ---------------------------------------------------------------------------
;;;; Editor glue
;;;; ---------------------------------------------------------------------------

(define (current-rope)
  (editor->text (editor->doc-id (editor-focus))))

;; The [from, to) char range of the focused document as a string.
(define (range-text rope from to)
  (text.rope->string (text.rope->slice rope from to)))

;; Apply `convert` (string -> string) to the text under every selection range.
;;
;; All ranges are read from the pre-edit rope first, then rewritten from the
;; highest offset down so earlier offsets stay valid. The selections are then
;; restored over the converted text, accounting for any length changes.
(define (switch-case convert)
  (let* ([rope (current-rope)]
         [spans (sort (map (lambda (r) (cons (range->from r) (range->to r)))
                       (selection->ranges (current-selection-object)))
                 (lambda (a b) (< (car a) (car b))))]
         [edits (map (lambda (span)
                      (let ([from (car span)] [to (cdr span)])
                        (list from to (convert (range-text rope from to)))))
                 spans)])
    (apply-edits! edits)
    (reselect! edits)))

;; Rewrite each (from to text) edit, highest offset first.
(define (apply-edits! edits)
  (for-each
    (lambda (e)
      (set-current-selection-object!
        (range->selection (range (car e) (cadr e))))
      (replace-selection-with (caddr e)))
    (sort edits (lambda (a b) (> (car a) (car b))))))

;; Put the selections back over the converted regions. `edits` are in ascending
;; offset order; each region shifts by the cumulative length change of the
;; regions before it.
(define (reselect! edits)
  (let loop ([es edits]
             [delta 0]
             [ranges '()])
    (cond
      [(null? es) (set-selection-ranges! (reverse ranges))]
      [else
        (let* ([e (car es)]
               [from (+ (car e) delta)]
               [len (string-length (caddr e))]
               [to (+ from len)]
               [delta (+ delta (- len (- (cadr e) (car e))))])
          (loop (cdr es) delta (cons (range from to) ranges)))])))

(define (set-selection-ranges! ranges)
  (when (pair? ranges)
    (set-current-selection-object! (range->selection (car ranges)))
    (for-each push-range-to-selection! (cdr ranges))))

;;;; ---------------------------------------------------------------------------
;;;; Commands
;;;; ---------------------------------------------------------------------------

;;@doc
;; Convert the selected text to UPPERCASE
(define (switch-to-uppercase) (switch-case to-uppercase))

;;@doc
;; Convert the selected text to lowercase
(define (switch-to-lowercase) (switch-case to-lowercase))

;;@doc
;; Flip the case of the selected text (aLTERNATE cASE)
(define (switch-to-alternate-case) (switch-case to-alternate-case))

;;@doc
;; Convert the selected text to PascalCase
(define (switch-to-pascal-case) (switch-case to-pascal-case))

;;@doc
;; Convert the selected text to camelCase
(define (switch-to-camel-case) (switch-case to-camel-case))

;;@doc
;; Convert the selected text to Title Case
(define (switch-to-title-case) (switch-case to-title-case))

;;@doc
;; Convert the selected text to Sentence case
(define (switch-to-sentence-case) (switch-case to-sentence-case))

;;@doc
;; Convert the selected text to snake_case
(define (switch-to-snake-case) (switch-case to-snake-case))

;;@doc
;; Convert the selected text to kebab-case
(define (switch-to-kebab-case) (switch-case to-kebab-case))
