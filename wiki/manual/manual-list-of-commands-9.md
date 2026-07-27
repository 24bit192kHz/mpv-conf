was cropped, or if there is padding. This number can be negative as well.
You access a pixel with `byte_index = y * stride + x * bpp`.
Here, `bpp` is the number of bytes per pixel, which is 8 for `rgba64`
format and 4 for other formats.

The `flags` argument is like the first argument to `screenshot` and
supports `subtitles`, `video`, `window`.

### Filter Commands

`af <operation> <value>`

Change audio filter chain. See `vf` command.

`vf <operation> <value>`

Change video filter chain.

The semantics are exactly the same as with option parsing (see
[VIDEO FILTERS](manual-video-filters-1.md)). As such the text below is a redundant and incomplete
summary.

The first argument decides what happens:

<set>

Overwrite the previous filter chain with the new one.

<add>

Append the new filter chain to the previous one.

<toggle>

Check if the given filter (with the exact parameters) is already in the
video chain. If it is, remove the filter. If it isn't, add the filter.
(If several filters are passed to the command, this is done for
each filter.)

A special variant is combining this with labels, and using `@name`
without filter name and parameters as filter entry. This toggles the
enable/disable flag.

<remove>

Like `toggle`, but always remove the given filter from the chain.

<clr>

Remove all filters. Note that like the other sub-commands, this does
not control automatically inserted filters.

The argument is always needed. E.g. in case of `clr` use `vf clr ""`.

You can assign labels to filter by prefixing them with `@name:` (where
`name` is a user-chosen arbitrary identifier). Labels can be used to
refer to filters by name in all of the filter chain modification commands.
For `add`, using an already used label will replace the existing filter.

The `vf` command shows the list of requested filters on the OSD after
changing the filter chain. This is roughly equivalent to
`show-text ${vf}`. Note that auto-inserted filters for format conversion
are not shown on the list, only what was requested by the user.

Normally, the commands will check whether the video chain is recreated
successfully, and will undo the operation on failure. If the command is run
before video is configured (can happen if the command is run immediately
after opening a file and before a video frame is decoded), this check can't
be run. Then it can happen that creating the video chain fails.

Example for input.conf

- `a vf set vflip` turn the video upside-down on the `a` key

- `b vf set ""` remove all video filters on `b`

- `c vf toggle gradfun` toggle debanding on `c`

Example how to toggle disabled filters at runtime

- Add something like `vf-add=@deband:!gradfun` to `mpv.conf`.
The `@deband:` is the label, an arbitrary, user-given name for this
filter entry. The `!` before the filter name disables the filter by
default. Everything after this is the normal filter name and possibly
filter parameters, like in the normal `--vf` syntax.

- Add `a vf toggle @deband` to `input.conf`. This toggles the
"disabled" flag for the filter with the label `deband` when the
`a` key is hit.

`vf-command <label> <command> <argument> [<target>]`

Send a command to the filter. Note that currently, this only works with
the `lavfi` filter. Refer to the libavfilter documentation for the list
of supported commands for each filter.

`<label>` is a mpv filter label, use `all` to send it to all filters
at once.

`<command>` and `<argument>` are filter-specific strings.

`<target>` is a filter or filter instance name and defaults to `all`.
Note that the target is an additional specifier for filters that
support them, such as complex `lavfi` filter chains.

`af-command <label> <command> <argument> [<target>]`

Same as `vf-command`, but for audio filters.

