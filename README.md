# quickref.el

Quickly record notes for yourself, which can then be displayed back to
you in the echo area on demand. Notes are organized by topic, and
relevant notes are typically deduced for you based on context. If your
current major-mode, any of its parents, or any active minor mode is
the name of a topic, those notes will be considered relevant and
displayed to you.

I use this as an easy way to remind myself of that fancy-new-keybinding
I found last week but can't ever remember when I need it:

![Example screenshot](https://github.com/pd/quickref.el/raw/master/screenshot.png)

## Installation
Use [MELPA](https://github.com/milkypostman/melpa): `M-x package-install quickref`.

Load it, enable it globally:

~~~ scheme
(require 'quickref)
(quickref-global-mode +1)
~~~

By default, all actions will be available beneath the prefix `C-c q`. You can
change this easily:

~~~ scheme
(setq quickref-command-prefix (kbd "C-M-q"))
(quickref-global-mode +1)
~~~

Your quickref entries are stored in the file named by `quickref-save-file`,
which defaults to `<user-emacs-directory>/quickrefs`. It's probably useful
to keep this file in source control;
[I do](https://github.com/pd/dotfiles/blob/master/emacs.d/store/quickrefs.el),
anyway.

## Usage
1. Guess relevant topics and display their notes in the echo area: `C-c q e`
2. Prompt for a topic and display its notes: `C-u C-c q e`
3. Display notes in a short window at the bottom of the selected window: `C-c q w`
4. Dismiss that window: `C-c q 0`
5. Add a note: `C-c q a`
6. Delete a note: `C-c q d`
7. Save your quickrefs to disk: `C-c q C-s`
8. Reload your quickrefs from disk: `C-c q C-l`
