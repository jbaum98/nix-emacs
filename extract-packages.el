(require 'use-package)

(setq nix-package-alist '())

(defun use-package-handler/:pin (name-symbol keyword archive-name rest state)
  (let* ((state (plist-put state :archive-name (intern archive-name)))
         (body (use-package-process-keywords name-symbol rest state)))
    nil))

(defun alist-append (x prop val)
  (alist-put x prop
             (cons val (alist-get x prop))))

(defun use-package-handler/:ensure (name-symbol keyword ensure rest state)
  (let* ((archive-name (or (plist-get state :archive-name) 'melpa)))
    (push name-symbol (alist-get archive-name nix-package-alist))
    nil))

(defun output-packages ()
 (dolist (archive-set nix-package-alist)
   (let ((archive-name (symbol-name (car archive-set)))
         (pkgs (cdr archive-set)))
     (with-temp-file archive-name
       (dolist (pkg pkgs)
         (insert (format "%s\n" pkg)))))))
