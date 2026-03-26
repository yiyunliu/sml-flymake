;;; sml-flymake.el --- A standard ml flymake backend -*- lexical-binding: t; -*-
(require 'cl-lib)
(defvar-local sml--flymake-proc nil)


(defun sml-flymake (report-fn &rest _args)
  "Run the flymake callback REPORT-FN after launching smlnj."
  ;; make sure smlnj is installed
  (unless (executable-find
	   "smlnj") (error "Cannot find a suitable sml"))


  ;; kill the previously launched process
  (when (process-live-p sml--flymake-proc)
    (kill-process sml--flymake-proc))


  (let ((source (current-buffer)))
    (widen)

    (setq
     sml--flymake-proc
     (make-process
      :name "sml-flymake" :noquery t :connection-type 'pipe
      :buffer (generate-new-buffer " *sml-flymake*")
      :stderr nil
      :command (list "smlnj")
      :sentinel
      (lambda (proc _event)
	(when (memq (process-status proc) '(exit signal))
	  (unwind-protect
	      (if (with-current-buffer source (eq proc sml--flymake-proc))
		  (with-current-buffer (process-buffer proc)
		    (goto-char (point-min))
		    (cl-loop
		     while (search-forward-regexp
			    "^.*:\\([0-9]+\\)\\.\\([0-9]+\\)-\\([0-9]+\\)\\.\\([0-9]+\\) Error: \\(.*\\)$"
			    nil t)
		     for msg = (match-string 5)
		     for (beg . end) = (flymake-diag-region
							source
							(string-to-number (match-string 1))
							(string-to-number (match-string 2)))
		     when (and beg end)
		     collect (flymake-make-diagnostic source
						      beg
						      end
						      :error
						      msg)
		     into diags
		     finally (funcall report-fn diags)))
		(flymake-log :warning "Canceling obsolete check %s"))
	    (kill-buffer (process-buffer proc)))))))
    (process-send-region sml--flymake-proc (point-min) (point-max))
    (process-send-eof sml--flymake-proc)))

(defun sml-setup-flymake-backend ()
  (add-hook 'flymake-diagnostic-functions 'sml-flymake nil t))

(add-hook 'sml-mode-hook 'sml-setup-flymake-backend)
