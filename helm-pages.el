;;; helm-pages.el --- Pages in current buffer as Helm datasource  -*- lexical-binding: t; -*-

;; Copyright (C) 2015  David Christiansen

;; Author: David Christiansen <david@davidchristiansen.dk>
;; Keywords: convenience, helm, outlines
;; Package-Requires: ((helm "1.6.5") (emacs "24") (cl-lib "0.5"))
;; Version: 1.0.0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Use the `helm' framework to navigate pages in a buffer.

;;; Code:

(require 'cl-lib)
(require 'helm)
(require 'helm-grep)


;;; Customize

(defgroup helm-pages nil
  "Helm pages."
  :prefix "helm-pages-")

(defcustom helm-pages-actions
  (helm-make-actions
   "Go to page" 'helm-pages-goto-page
   "Narrow to page" 'helm-pages-narrow-to-page)
  "Actions for `helm-pages'."
  :group 'helm-pages
  :type '(alist :key-type string :value-type function))


;;; Functions to get buffer pages info

(defun helm-pages-get-next-header ()
  "Return the next non-blank line after point."
  (with-helm-current-buffer
    (save-excursion
      (save-restriction
        (narrow-to-page)
        (beginning-of-line)
        (while (and (not (eobp))
                    (looking-at-p "^\\s-*$"))
          (forward-line))
        (let* ((start (progn (beginning-of-line) (point)))
               (end (progn (end-of-line) (point))))
          (buffer-substring start end))))))

(defun helm-pages-get-pages ()
  "Return a list of (POS . HEADER) pairs.

POS is the position of the beginning of a page.  HEADER is the
page's first non-blank line ."
  (with-helm-current-buffer
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (let ((pages (list (cons (point) (helm-pages-get-next-header)))))
          (while (re-search-forward page-delimiter nil t)
            (forward-line)
            (push (cons (point) (helm-pages-get-next-header))
                  pages))
          (nreverse pages))))))


;;; Helm actions

(defun helm-pages-goto-page (pos)
  "Go to the page at position POS, preserving narrowing."
  (with-helm-current-buffer
    (let ((narrowed (buffer-narrowed-p)))
      (widen)
      (goto-char pos)
      (recenter-top-bottom 0)
      (when narrowed (narrow-to-page)))))

(defun helm-pages-narrow-to-page (pos)
  "Narrow buffer to the page at position POS."
  (with-helm-current-buffer
    (goto-char pos)
    (recenter-top-bottom 0)
    (narrow-to-page)))

(defun helm-pages-preview (pos)
  "Preview the selected page.

Intended for use as a Helm persistent action."
  (switch-to-buffer helm-current-buffer)
  (goto-char pos)
  (helm-highlight-current-line))


;;; Helm sources

(defun helm-pages-name (&optional _name)
  "Get the name of the `helm-pages' source.
Optional argument _NAME is Helm's name."
  (with-helm-current-buffer
    (or
     (ignore-errors (concat "Pages in " (buffer-name)))
     "Pages")))

(defun helm-pages-candidates ()
  "Get the Helm view of the buffer's pages."
  (with-helm-current-buffer
    (cl-loop for (pos . header) in (helm-pages-get-pages)
             for max-line-length = (length (number-to-string (count-lines (point-min) (point-max))))
             for lineno = (number-to-string (line-number-at-pos pos))
             collect (cons (concat (propertize (concat lineno ": ") 'face 'helm-grep-lineno)
                                   (make-string (- max-line-length (length lineno)) ?\s)
                                   header)
                           pos))))


;;; API

;;;###autoload
(defun helm-pages ()
  "View the pages in the current buffer with Helm."
  (interactive)
  (helm :sources (helm-build-sync-source (helm-pages-name)
                   :action helm-pages-actions
                   :candidates (helm-pages-candidates)
                   :persistent-action 'helm-pages-preview
                   :persistent-help "View page"
                   :follow 1)
        :buffer "*helm-pages*"))

(provide 'helm-pages)
;;; helm-pages.el ends here
