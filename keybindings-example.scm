;; Example key bindings for change-case, reproducing the "case mode" under the
;; backtick (`) prefix proposed in helix-editor/helix#12043. Copy into init.scm.

(keymap (global)
  (normal ("`"
           (a ":switch-to-alternate-case")
           (u ":switch-to-uppercase")
           (l ":switch-to-lowercase")
           (p ":switch-to-pascal-case")
           (c ":switch-to-camel-case")
           (t ":switch-to-title-case")
           (S ":switch-to-sentence-case")
           (s ":switch-to-snake-case")
           (k ":switch-to-kebab-case")))
  (select ("`"
           (a ":switch-to-alternate-case")
           (u ":switch-to-uppercase")
           (l ":switch-to-lowercase")
           (p ":switch-to-pascal-case")
           (c ":switch-to-camel-case")
           (t ":switch-to-title-case")
           (S ":switch-to-sentence-case")
           (s ":switch-to-snake-case")
           (k ":switch-to-kebab-case"))))
