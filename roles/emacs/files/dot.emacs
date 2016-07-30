(global-set-key "\C-h" 'delete-backward-char)
(global-set-key [f1] 'help-command)


;; MELPA

(require 'package)
(add-to-list 'package-archives
             '("melpa" . "https://stable.melpa.org/packages/") t)
(package-initialize)


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


;; Auto-Complete

(require 'auto-complete)


;; Flycheck

(add-hook 'after-init-hook #'global-flycheck-mode)


;; Haskell Mode Setup

(add-to-list 'load-path "/usr/local/share/emacs/site-lisp/haskell-mode")
(load "haskell-mode-autoloads.el")

(setq auto-mode-alist (cons '("\\.hs$" . haskell-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.lhs$" . haskell-mode) auto-mode-alist))
(add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)
(add-hook 'haskell-mode-hook 'turn-on-haskell-doc-mode)


;; Haskell Flycheck
;;
;; You need to install flycheck-haskell for this to work

(autoload 'ghc-init "ghc" nil t)
(autoload 'ghc-debug "ghc" nil t)
(add-hook 'haskell-mode-hook 'flycheck-mode)
(add-hook 'haskell-mode-hook 'ghc-init)


;; Haskell Autocomplete

(ac-define-source ghc-mod
  '((depends ghc)
    (candidates . (ghc-select-completion-symbol))
    (symbol . "s")
    (cache)))

(defun my-ac-haskell-mode ()
  (setq ac-sources '(ac-source-words-in-same-mode-buffers
                     ac-source-dictionary
                     ac-source-ghc-mod)))

(add-hook 'haskell-mode-hook 'my-ac-haskell-mode)

(defun my-haskell-ac-init ()
  (when (member (file-name-extension buffer-file-name) '("hs" "lhs"))
    (auto-complete-mode t)
    (setq ac-sources '(ac-source-words-in-same-mode-buffers
                       ac-source-dictionary
                       ac-source-ghc-mod))))

(add-hook 'find-file-hook 'my-haskell-ac-init)