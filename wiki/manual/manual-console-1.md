# CONSOLE

This script provides the ability to process the user's textual input to other
scripts through the `mp.input` API. It can be displayed on both the video
window and the terminal. It can be disabled entirely using the
`--load-console=no` option.

Console can either process free-form text or select from a predefined list of
items.

## Free-form text mode keybindings

ESC and Ctrl+[

Hide the console.

ENTER, Ctrl+j and Ctrl+m

Select the first completion if one wasn't already manually selected, and run
the typed command.

Shift+ENTER

Type a literal newline character.

LEFT and Ctrl+b

Move the cursor to the previous character.

RIGHT and Ctrl+f

Move the cursor to the next character.

Ctrl+LEFT and Alt+b

Move the cursor to the beginning of the current word, or if between words,
to the beginning of the previous word.

Ctrl+RIGHT and Alt+f

Move the cursor to the end of the current word, or if between words, to the
end of the next word.

HOME and Ctrl+a

Move the cursor to the start of the current line.

END and Ctrl+e

Move the cursor to the end of the current line.

BACKSPACE and Ctrl+h

Delete the previous character.

Ctrl+d

Hide the console if the current line is empty, otherwise delete the next
character.

Ctrl+BACKSPACE and Ctrl+w

Delete text from the cursor to the beginning of the current word, or if
between words, to the beginning of the previous word.

Ctrl+DEL and Alt+d

Delete text from the cursor to the end of the current word, or if between
words, to the end of the next word.

Ctrl+u

Delete text from the cursor to the beginning of the current line.

Ctrl+k

Delete text from the cursor to the end of the current line.

Ctrl+c

Clear the current line.

UP and Ctrl+p

Move back in the command history.

DOWN and Ctrl+n

Move forward in the command history.

PGUP

Go to the first command in the history.

PGDN

Stop navigating the command history.

Ctrl+r

Search the command history. See [SELECT](manual-select.md) for the key bindings in this mode.

INSERT

Toggle insert mode.

Ctrl+v

Paste text (uses the clipboard on X11 and Wayland).

Shift+INSERT

Paste text (uses the primary selection on X11 and Wayland).

Ctrl+y

Copy the current line to the clipboard.

TAB and Ctrl+i

Cycle through completions.

Shift+TAB

Cycle through the completions backwards.

Ctrl+l

Clear all log messages from the console.

MBTN_MID

Paste text (uses the primary selection on X11 and Wayland).

WHEEL_UP

Move back in the command history.

WHEEL_DOWN

Move forward in the command history.

## Known issues

- Non-ASCII keyboard input has restrictions

- The cursor keys move between Unicode code-points, not grapheme clusters

## Configuration

This script can be customized through a config file `script-opts/console.conf`
placed in mpv's user directory and through the `--script-opts` command-line
option. The configuration syntax is described in [mp.options functions](manual-lua-scripting-1.md).

