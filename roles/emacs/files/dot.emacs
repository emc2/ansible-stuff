(global-set-key "\C-h" 'delete-backward-char)
(global-set-key [f1] 'help-command)

;; Disable hard tabs
(setq-default indent-tabs-mode nil)

;; Whitespace mode
(require 'whitespace)
(setq whitespace-style '(face trailing lines-tail))
;(setq whitespace-display-mappings '((tab-mark 9 [9654 9] [92 9])))
(setq whitespace-line-column 80)
(global-whitespace-mode 1)
(add-hook 'before-save-hook 'delete-trailing-whitespace)

;; Highlight the line we're on
(global-hl-line-mode 1)
(set-face-background 'hl-line "grey")

;; Haskell stuff
(add-to-list 'load-path "/usr/local/share/emacs/site-lisp/haskell-mode")
(require 'haskell-mode-autoloads)

(setq auto-mode-alist (cons '("\\.hs$" . haskell-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.lhs$" . haskell-mode) auto-mode-alist))
(add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)
(add-hook 'haskell-mode-hook 'turn-on-haskell-doc-mode)

