# switch-case.hx

Text case conversion commands for the [Helix editor](https://helix-editor.com).

Converts the text under each selection between UPPERCASE, lowercase, aLTERNATE cASE, PascalCase, camelCase, Title Case, Sentence case, snake_case and kebab-case.

## Commands

| Command                     | Result                           |
| --------------------------- | -------------------------------- |
| `:switch-to-uppercase`      | `HELLO WORLD`                    |
| `:switch-to-lowercase`      | `hello world`                    |
| `:switch-to-alternate-case` | flips the case of each character |
| `:switch-to-pascal-case`    | `HelloWorld`                     |
| `:switch-to-camel-case`     | `helloWorld`                     |
| `:switch-to-title-case`     | `Hello World`                    |
| `:switch-to-sentence-case`  | `Hello world`                    |
| `:switch-to-snake-case`     | `hello_world`                    |
| `:switch-to-kebab-case`     | `hello-world`                    |

### Conversion rules

Word boundaries are inferred from two sources, so any input style converts to any other:

- non-alphanumeric separators (spaces, `_`, `-`, and the like), and
- camelCase transitions, where a lower-case character is followed by an upper-case one.

UPPERCASE, lowercase, aLTERNATE cASE, Title Case and Sentence case preserve the text’s punctuation, spacing, and newlines, changing only letter case. PascalCase, camelCase, snake_case and kebab-case re-tokenise the words: they drop punctuation and leading whitespace, collapse runs of separators to a single separator, and join the words with their separator. Newlines are preserved in every style: each line is converted independently.

## Installation

Install with [forge](https://github.com/mattwparas/steel), Steel’s package manager:

```sh
forge pkg install --git https://github.com/waddie/switch-case.hx
```

Then load the plugin in your `init.scm`:

```scheme
(require "switch-case/switch-case.scm")
```

## Key bindings

```scheme
(keymap (global)
  (normal ("`"
           (u ":switch-to-uppercase")
           (l ":switch-to-lowercase")
           (a ":switch-to-alternate-case")
           (p ":switch-to-pascal-case")
           (c ":switch-to-camel-case")
           (t ":switch-to-title-case")
           (S ":switch-to-sentence-case")
           (s ":switch-to-snake-case")
           (k ":switch-to-kebab-case")))
  (select ("`"
           (u ":switch-to-uppercase")
           (l ":switch-to-lowercase")
           (a ":switch-to-alternate-case")
           (p ":switch-to-pascal-case")
           (c ":switch-to-camel-case")
           (t ":switch-to-title-case")
           (S ":switch-to-sentence-case")
           (s ":switch-to-snake-case")
           (k ":switch-to-kebab-case"))))
```

## Licence

AGPL-3.0-or-later. See [LICENSE](LICENSE).
