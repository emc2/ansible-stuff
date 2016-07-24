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
