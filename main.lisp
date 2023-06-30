;;;; Port of the bkmks dmenu script from the suckless website, with my own twist.

;;; TODO
;;; - Fix the need to put double quotes for certain links, when adding new entries

(defparameter *config* (load-config *config-path*))
(defparameter *browser* (getf *config* 'browser))
(defparameter *preferred-menu* (getf *config* 'menu))
(defparameter *files* (getf *config* 'files))
(defparameter *file-state* (getf *config* 'current-file))
(defparameter *current-file* (nth *file-state* *files*))

;; TODO update the help
(defun show-usage ()
  (show-dialog (format nil "
bkmks: unix bookmark management that sucks less. Lisp edition!
       usage:
         bkmks h[elp]
           show this help message
         bkmks a[dd] <url>
           add a new bookmark
         bkmks d[el] <selected entry>
           delete an entry
         bkmks c[hg] <selected entry>
           change current bookmark category
         bkmks cata[dd] <selected entry>
           adds a new category
         bkmks catd[el] <selected entry>
           deletes a category
         bkmks [ls]
           show all bookmarks and go to link in prefered browser

       Configuration is done by editing the configuration file, located at /home/user/.config/bkmks/

       If you would prefer to have your bookmarks stored in an alternate location, there are also variables that can be changed for that. The default is /home/user/.config/bkmks/files/urls~%")))

(defun bkmks-get-categories ()
  (update-config)
  (let* ((files (get-directory-files *url-file-path-list*))
         (files-length (format nil "~s" (length *url-file-path-list*)))
         (tmp #P "/tmp/bkmks-change.tmp")
         (raw-entry "")
         (filtered-entry ""))
    (overwrite-file! tmp (format nil "~{~A~%~}" files))
    (setq raw-entry (launch-dmenu files-length tmp))
    (setq filtered-entry (merge-pathnames *url-file-path* (pathname raw-entry)))
    `(,filtered-entry ,raw-entry)))

(defun bkmks-check ()
  (ensure-directories-exist *url-file-path*)
  (cond ((null (probe-file *current-file*))
         (show-dialog (format nil "Error: No bookmarks found to display. Try adding some!~%~%")))
        (t (format nil "Everything OK."))))

(defun bkmks-get-categories ()
  (update-config)
  (let* ((files (get-directory-files *url-file-path-list*))
         (files-length (format nil "~s" (length *url-file-path-list*)))
         (tmp #P "/tmp/bkmks-change.tmp")
         (raw-entry "")
         (filtered-entry ""))
    (overwrite-file! tmp (format nil "~{~A~%~}" files))
    (setq raw-entry (launch-dmenu files-length tmp))
    (setq filtered-entry (merge-pathnames *url-file-path* (pathname raw-entry)))
    `(,filtered-entry ,raw-entry)))


(defun bkmks-display ()
  (bkmks-check)
  (let ((bkmks-length  (get-file-lines *current-file*))
        (raw-entry "")
        (filtered-entry "")
        (current-file (pathname-name *current-file*)))
    (setq raw-entry (launch-dmenu bkmks-length *current-file* current-file))
    (format nil "~a" bkmks-length)
    (setq filtered-entry (cl-ppcre:scan-to-strings "(?<=\\|\\s).\+" (string-trim '(#\NewLine) raw-entry)))
    `(,filtered-entry ,(string-trim '(#\NewLine) raw-entry))))

(defun bkmks-add ()
  (let ((desc ""))
    (if (null (nth 2 sb-ext:*posix-argv*))
        (show-dialog (format nil "Error: url must be provided.~%~%") :justify "center")
        (progn
          (setq desc (launch-dmenu-prompt "Description: "))
          (append->file (nth 2 sb-ext:*posix-argv*) (string-trim '(#\NewLine) desc) *current-file*)))))

(defun bkmks-del ()
  (bkmks-check)
  (let* ((entry (nth 1 (bkmks-display)))
         (removed-lines (remove-lines *current-file* entry)))
    (overwrite-file! *current-file* removed-lines)))

(defun bkmks-change ()
  (update-config)
  (let ((category (nth 0 (bkmks-get-categories))))
    (set-config! *config* 'current-file (index-of *url-file-path-list* category 0))
    (bkmks-send)))

(defun bkmks-del-category ()
  (let* ((category (nth 0 (bkmks-get-categories)))
         (index (getf *config* 'current-file))
         (prompt (string-downcase (launch-dmenu-prompt (format nil "(Deleting: ~A) Are you sure? (y/N): " (pathname-name category))))))
    (if (null (find prompt '("y" "yes") :test #'string-equal))
        nil
        (progn
          (set-config! *config* 'current-file (if (equal index 0) 0
                                                  (1- index)))
          (delete-file category)))
    (update-config)))

(defun bkmks-add-category ()
  (let* ((category-name (launch-dmenu-prompt "Enter category name: "))
         (category-file (merge-pathnames *url-file-path* (pathname category-name))))
    (if (probe-file category-file)
        (show-dialog (format nil "This category already exists."))
        (overwrite-file! category-file ""))
    (update-config)))

(defun bkmks-send ()
  (let ((entry (nth 0 (bkmks-display))))
    (uiop:run-program `(,*browser* ,entry))))

(defun main ()
  (check-config (load-config *config-path*))
  (update-config)
  (cond
    ((find (nth 1 sb-ext:*posix-argv*) '("add" "a") :test #'string-equal)
     (bkmks-add))
    ((find (nth 1 sb-ext:*posix-argv*) '("catadd" "cata" "ca") :test #'string-equal)
     (bkmks-add-category))
    ((find (nth 1 sb-ext:*posix-argv*) '("del" "d") :test #'string-equal)
     (bkmks-del))
    ((find (nth 1 sb-ext:*posix-argv*) '("catdel" "catd" "cd") :test #'string-equal)
     (bkmks-del-category))
    ((find (nth 1 sb-ext:*posix-argv*) '("chg" "c") :test #'string-equal)
     (bkmks-change))
    ((find (nth 1 sb-ext:*posix-argv*) '("help" "h") :test #'string-equal)
     (show-usage))
    ((find (nth 1 sb-ext:*posix-argv*) '("nil" "ls") :test #'string-equal)
     (bkmks-send))
    (t (show-usage))))
