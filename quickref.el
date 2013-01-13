;;; quickref.el --- Display relevant notes-to-self in the echo area

;; Author: Kyle Hargraves
;; URL: https://github.com/pd/quickref.el
;; Version: 0.2
;; Package-Requires: ((dash "1.0.3") (s "1.0.0"))

;;; TODO:
;; cukes would be nice
;; quickref-guess-topics-by-thing-at-point
;; quickref-propertize-{label,note}-functions: list of functions that
;;   will apply new properties to labels and notes; these could make
;;   it possible to click an fn name to view its docs, or click a
;;   keybinding to run it, etc.

(require 'dash)
(require 's)

(defgroup quickref nil
  "Display notes-to-self in the echo area."
  :group 'help)

(defcustom quickref-command-prefix (kbd "C-c q")
  "The prefix for all quickref key commands."
  :type 'string
  :group 'quickref)

(defcustom quickref-save-file (expand-file-name "quickrefs" user-emacs-directory)
  "File in which to save your quickref definitions."
  :type 'file
  :group 'quickref)

(defcustom quickref-guess-topics-functions '(quickref-guess-topic-by-major-mode
                                             quickref-guess-topics-by-derived-mode
                                             quickref-guess-topics-by-minor-modes)
  "List of functions, called in order, to be used to guess the
relevant quickref topics. The function will be called with no
arguments, and should return the name of a topic to display,
a list of topic names, or nil if none."
  :type 'list
  :group 'quickref)

(defcustom quickref-show-guesses 'all
  "Whether to display the notes of only the first guessed topic,
or the notes of all guessed topics."
  :type '(choice (const :tag "Never guess" nil)
                 (symbol :tag "First guess" 'first)
                 (symbol :tag "All guesses" 'all))
  :group 'quickref)

(defcustom quickref-separator " | "
  "The separator to be placed between notes displayed in the echo area."
  :type 'string
  :group 'quickref)

(defcustom quickref-format-label-function
  (lambda (label) (propertize label 'face 'quickref-label-face))
  "Function used to format the label."
  :type 'function
  :group 'quickref)

(defcustom quickref-format-note-function
  (lambda (note) (propertize note 'face 'quickref-note-face))
  "Function used to format the note."
  :type 'function
  :group 'quickref)

(defcustom quickref-message-function 'message
  "Function used to display the quickref message."
  :type 'function
  :group 'quickref)

(defface quickref-label-face
  '((t :inherit font-lock-function-name-face))
  "Face for label name."
  :group 'quickref)

(defface quickref-note-face
  '((t :inherit default-face))
  "Face for note."
  :group 'quickref)

(defface quickref-separator-face
  '((t :inherit font-lock-comment-face))
  "Face for separator between notes."
  :group 'quickref)

(define-prefix-command 'quickref-mode-keymap)
(define-key quickref-mode-keymap (kbd "e") 'quickref-in-echo-area)
(define-key quickref-mode-keymap (kbd "a") 'quickref-add-note)
(define-key quickref-mode-keymap (kbd "d") 'quickref-delete-note)
(define-key quickref-mode-keymap (kbd "v") 'quickref-describe-refs)
(define-key quickref-mode-keymap (kbd "C-s") 'quickref-write-save-file)
(define-key quickref-mode-keymap (kbd "C-l") 'quickref-load-save-file)

(defvar quickref-refs nil
  "The list of quickref topics mapped to their notes.")

(defun quickref-guess-topics ()
  (let ((guesses (-reject 'null (mapcar 'funcall quickref-guess-topics-functions))))
    (-distinct
     (-flatten (cond
                ((null quickref-show-guesses) nil)
                ((equal quickref-show-guesses 'first) (car guesses))
                (t guesses))))))

(defun quickref-guess-topic-by-major-mode ()
  "If the current `major-mode' is an available topic, return it."
  (and (assoc (symbol-name major-mode) quickref-refs)
       (symbol-name major-mode)))

(defun quickref-guess-topics-by-derived-mode ()
  "If the current `major-mode' is derived from any topic, return those topics."
  (let ((topics (mapcar 'car quickref-refs)))
    (--select (derived-mode-p (intern it)) topics)))

(defun quickref-guess-topics-by-minor-modes ()
  "Return the list of active minor modes which are available topics."
  (let ((active-modes (--filter (and (boundp it) (symbolp it) (symbol-value it))
                                minor-mode-list)))
    (--filter (assoc it quickref-refs)
              (mapcar 'symbol-name active-modes))))

(defun quickref-read-topic ()
  (let ((topic-names (mapcar 'car quickref-refs))
        (guessed (car (quickref-guess-topics))))
    (if (fboundp 'ido-completing-read)
        (ido-completing-read "Topic: " topic-names nil nil nil nil guessed)
      (completing-read "Topic: " topic-names nil nil  nil nil guessed))))

(defun quickref-read-label (&optional topic)
  (let ((default-labels (when topic (mapcar 'car (cdr (assoc topic quickref-refs))))))
    (if default-labels
        (if (fboundp 'ido-completing-read)
            (ido-completing-read "Label: " default-labels)
          (completing-read "Label: " default-labels))
      (read-from-minibuffer "Label: "))))

(defun quickref-read-note ()
  (read-from-minibuffer "Note: "))

(defun quickref-format (label &optional note)
  (let ((label (if (consp label) (car label) label))
        (note  (if (consp label) (cdr label) note)))
    (format "%s %s"
            (funcall quickref-format-label-function label)
            (funcall quickref-format-note-function note))))

(defun quickref-notes (topic)
  "Returns the notes for the given topic."
  (cdr (assoc topic quickref-refs)))

(defun quickref-join-into-lines (msgs sep)
  "Joins series of strings MSGS with SEP, inserting a newline before
any string that would cause the length of the current line to exceed
the width of the echo area."
  (let ((ea-width (1- (window-width (minibuffer-window))))
        (reduction (lambda (lines msg)
                     (let ((curline (car lines))
                           (addlen  (+ (length sep) (length msg))))
                       (cond
                        ((null lines)
                         (list msg))

                        ((> (+ (length curline) addlen) ea-width)
                         (cons msg lines))

                        (t (cons (concat curline sep msg) (cdr lines))))))))
    (s-join "\n" (nreverse (-reduce-from reduction nil msgs)))))

(defun quickref-build-message (notes)
  "Generate the full message to be displayed for NOTES."
  (quickref-join-into-lines (mapcar 'quickref-format notes)
                            (propertize quickref-separator 'face 'quickref-separator-face)))

;; Interactive
;;;###autoload
(defun quickref-in-echo-area (topics)
  "Display quickref in the echo area."
  (interactive (list
                (let ((guessed (quickref-guess-topics)))
                  (if (or current-prefix-arg (null guessed)) (list (quickref-read-topic))
                    (quickref-guess-topics)))))
  (let ((notes (-reject 'null (mapcar 'quickref-notes topics))))
    (funcall quickref-message-function "%s" (quickref-build-message (apply 'append notes)))))

;;;###autoload
(defun quickref-add-note (topic label note)
  "Add a new quickref note."
  (interactive (list (quickref-read-topic)
                     (quickref-read-label)
                     (quickref-read-note)))
  (let ((entry (cons label note))
        (ref   (assoc topic quickref-refs)))
    (if ref
        (nconc (cdr ref) (list entry))
      (nconc quickref-refs (list (cons topic (list entry)))))))

;;;###autoload
(defun quickref-delete-note (topic label)
  "Delete a quickref note."
  (interactive
   (let ((topic (quickref-read-topic)))
     (list topic (quickref-read-label topic))))
  (let ((ref (assoc topic quickref-refs)))
    (when ref (assq-delete-all label ref))))

;;;###autoload
(defun quickref-load-save-file ()
  "If `quickref-save-file' exists, sets `quickref-refs' to
the contents therein."
  (interactive)
  (when (file-exists-p quickref-save-file)
    (with-temp-buffer
      (insert-file-contents quickref-save-file)
      (setq quickref-refs (read (buffer-string))))))

;;;###autoload
(defun quickref-write-save-file ()
  "Writes the pretty printed contents of `quickref-refs' to
the file at `quickref-save-file'."
  (interactive)
  (save-excursion
    (find-file quickref-save-file)
    (delete-region (point-min) (point-max))
    (insert ";; -*- mode: emacs-lisp -*-\n")
    (insert (pp-to-string quickref-refs))
    (save-buffer)
    (kill-buffer)))

;;;###autoload
(defun quickref-describe-refs ()
  "`describe-variable' `quickref-refs'."
  (interactive)
  (describe-variable 'quickref-refs))

;;;###autoload
(defun turn-on-quickref-mode ()
  "Turn on `quickref-mode'."
  (interactive)
  (quickref-mode +1))

;;;###autoload
(defun turn-off-quickref-mode ()
  "Turn off `quickref-mode'."
  (interactive)
  (quickref-mode -1))

;;;###autoload
(define-minor-mode quickref-mode
  "Quickly display notes you've made to yourself."
  :init-value nil
  :lighter " qr"
  :keymap `((,quickref-command-prefix . quickref-mode-keymap))
  (when (and quickref-mode (null quickref-refs)) (quickref-load-save-file)))

;;;###autoload
(define-globalized-minor-mode quickref-global-mode
  quickref-mode
  turn-on-quickref-mode)

(provide 'quickref)

;;; quickref.el ends here
