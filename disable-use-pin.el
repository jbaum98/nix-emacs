(eval-when-compile
  (declare-function use-package-process-keywords "use-package" (name-symbol rest state)))

(with-eval-after-load "use-package"
    (defun use-package-handler/:pin (name-symbol keyword archive-name rest state)
      (let* ((body (use-package-process-keywords name-symbol rest state)))
        body))

    (defun use-package-handler/:ensure (name-symbol keyword ensure rest state)
      (let* ((body (use-package-process-keywords name-symbol rest state)))
        body))
    )
