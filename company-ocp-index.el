;; company-ocp-index --- company-mode completion back-end for caml-mode

;; Copyright (C) 2014  Nicolas Ojeda Bar

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(defgroup company-ocp-index nil
  "Completion back-end for ocaml using `ocp-index'."
  :group 'company)

(defcustom company-ocp-index-path
  (executable-find "ocp-index")
  "Path to access the ocp-index command."
  :group 'company-ocp-index :type 'file)

(defcustom company-ocp-index-options "--show=types"
  "Command-line parameters to add to ocp-index invocations (ex. --show=sigs)"
  :group 'company-ocp-index :type 'string)

(defvar company-ocp-index--debug nil)

(defun company-ocp-index--debug-mode ()
  "Display command sent to ocp-index in the *Message* buffer"
  (interactive nil)
  (if company-ocp-index--debug
      (progn (message "ocp-index debug mode disabled")
	     (setq company-ocp-index--debug nil))
    (message "ocp-index debug mode enabled")
    (setq company-ocp-index--debug t)))

(defun company-ocp-index--args (cmd &rest args)
  (let*
      ((current-module (upcase-initials
                        (file-name-nondirectory
                         (file-name-sans-extension (buffer-file-name)))))
       (cmd (list* cmd company-ocp-index-options
                   "--full-open" current-module
                   "--context" ":"
                   args)))
    (when company-ocp-index--debug
      (message "%s" (mapconcat
                     (lambda (s) (format "\"%s\"" s))
                     (list* company-ocp-index-path cmd) " ")))
    cmd))

;; Taken from ocp-index.el
(defun company-ocp-index--run (cmd &rest args)
  (let* ((args (apply 'company-ocp-index--args cmd args))
         (shell-command (format "exec %s \"$@\"" company-ocp-index-path)))
    (with-output-to-string
      (let ((ret
             (apply 'call-process-region (point-min) (point)
                    shell-file-name
                    nil (list standard-output nil) nil
                    (list* shell-command-switch shell-command
                           company-ocp-index-path args))))
        (when (= 127 ret)
          (error "Could not find the Ocp-index program %S" company-ocp-index-path))))))

;; Taken from ocp-index.el
(defun company-ocp-index--prefix-bounds ()
  "Matches the fully qualified identifier at point, eg [M1.M2.someval] but
   also somerecord.[M1.M2.somefield]"
  (let ((case-fold-search nil))
    (save-excursion
      (while (looking-back "\\<\\([A-Z][a-zA-Z0-9_']*\.\\)*[a-zA-Z0-9_']*"
                           (line-beginning-position) nil)
        (goto-char (match-beginning 0)))
      (when (looking-at "[a-zA-Z0-9_'.]*[a-zA-Z0-9_']")
        (cons (match-beginning 0) (match-end 0))))))

(defun company-ocp-index--prefix ()
  (lexical-let ((bounds (company-ocp-index--prefix-bounds)))
    (when bounds
      (buffer-substring (car bounds) (point)))))

(defun company-ocp-index--candidates (prefix)
  (let* ((output (ocp-index-run "complete" "--sexp" prefix))
         (data (car-safe (read-from-string output))))
    (dolist (entry data (mapcar 'car data))
      (let* ((info (cdr entry))
             (type (cdr (assoc :type info)))
             (kind (cdr (assoc :kind info)))
             (doc (cdr (assoc :doc info))))
        (put-text-property 0 1 'type type (car entry))
        (put-text-property 0 1 'kind kind (car entry))
        (put-text-property 0 1 'doc doc (car entry))))))

(defun company-ocp-index--doc-buffer (candidate)
  (company-doc-buffer (get-text-property 0 'doc candidate)))

(defun company-ocp-index--location (candidate)
  (let* ((output (ocp-index-run "locate" candidate))
         (loc (car (split-string output "\n" t))))
    (when (and loc (string-match "^\\([^:]*\\):\\([0-9]\+\\):\\([0-9]\+\\)$" loc))
      (let ((file (match-string 1 loc))
            (line (string-to-number (match-string 2 loc))))
        (cons file line)))))

(defun company-ocp-index--meta (candidate)
  (get-text-property 0 'type candidate))

(defun company-ocp-index--annotation (candidate)
  (let ((anno (get-text-property 0 'kind candidate)))
    (when anno (concat " " anno))))

(defun company-ocp-index (command &optional arg &rest ignored)
  "`company-mode' completion back-end for ocp-index."
  (interactive (list 'interactive))
  (case command
    (interactive (company-begin-backend 'company-ocp-index))
    (prefix (company-ocp-index--prefix))
    (candidates (company-ocp-index--candidates arg))
    (meta (company-ocp-index--meta arg))
    (annotation (company-ocp-index--annotation arg))
    (doc-buffer (company-ocp-index--doc-buffer arg))
    (location (company-ocp-index--location arg))))
 
(provide 'company-ocp-index)
