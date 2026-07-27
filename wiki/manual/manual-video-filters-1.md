# VIDEO FILTERS

Video filters allow you to modify the video stream and its properties. All of
the information described in this section applies to audio filters as well
(generally using the prefix `--af` instead of `--vf`).

The exact syntax is:

`--vf=<filter1[=parameter1:parameter2:...],filter2,...>`

Setup a chain of video filters. This consists on the filter name, and an
option list of parameters after `=`. The parameters are separated by
`:` (not `,`, as that starts a new filter entry).

Before the filter name, a label can be specified with `@name:`, where
name is an arbitrary user-given name, which identifies the filter. This
is only needed if you want to toggle the filter at runtime.

A `!` before the filter name means the filter is disabled by default. It
will be skipped on filter creation. This is also useful for runtime filter
toggling.

See the `vf` command (and `toggle` sub-command) for further explanations
and examples.

This is an object settings list option. See [List Options](manual-options-track.md) for details.

The general filter entry syntax is:

> `["@"<label-name>":"] ["!"] <filter-name> [ "=" <filter-parameter-list> ]`

or for the special "toggle" syntax (see `vf` command):

> `"@"<label-name>`

and the `filter-parameter-list`:

> `<filter-parameter> | <filter-parameter> "," <filter-parameter-list>`

and `filter-parameter`:

> `(
>
>  "="
>
>  ) |
>
> `

`param-value` can further be quoted in `[` / `]` in case the value
contains characters like `,` or `=`. This is used in particular with
the `lavfi` filter, which uses a very similar syntax as mpv (MPlayer
historically) to specify filters and their parameters.

Note

`--vf` can only take a single track as input, even if the filter supports
dynamic input. Filters that require multiple inputs can't be used.
Use `--lavfi-complex` for such a use case. This also applies for `--af`.

Filters can be manipulated at run time. You can use `@` labels as described
above in combination with the `vf` command (see [COMMAND INTERFACE](manual-input-conf.md)) to get
more control over this. Initially disabled filters with `!` are useful for
this as well.

Note

To get a full list of available video filters, see `--vf=help` and
[https://ffmpeg.org/ffmpeg-filters.html](https://ffmpeg.org/ffmpeg-filters.html) .

Also, keep in mind that most actual filters are available via the `lavfi`
wrapper, which gives you access to most of libavfilter's filters. This
includes all filters that have been ported from MPlayer to libavfilter.

Most builtin filters are deprecated in some ways, unless they're only available
in mpv (such as filters which deal with mpv specifics, or which are
implemented in mpv only).

If a filter is not builtin, the `lavfi-bridge` will be automatically
tried. This bridge does not support help output, and does not verify
parameters before the filter is actually used. Although the mpv syntax
is rather similar to libavfilter's, it's not the same. (Which means not
everything accepted by vf_lavfi's `graph` option will be accepted by
`--vf`.)

You can also prefix the filter name with `lavfi-` to force the wrapper.
This is helpful if the filter name collides with a deprecated mpv builtin
filter. For example `--vf=lavfi-scale=args` would use libavfilter's
`scale` filter over mpv's deprecated builtin one.

Video filters are managed in lists. There are a few commands to manage the
filter list.

`--vf-append=filter`

Appends the filter given as arguments to the filter list.

`--vf-add=filter`

Appends the filter given as arguments to the filter list. (Passing multiple
filters is currently still possible, but deprecated.)

`--vf-pre=filter`

Prepends the filters given as arguments to the filter list. (Passing
multiple filters is currently still possible, but deprecated.)

`--vf-remove=filter`

Deletes the filter from the list. The filter can be either given the way it
was added (filter name and its full argument list), or by label (prefixed
with `@`). Matching of filters works as follows: if either of the compared
filters has a label set, only the labels are compared. If none of the
filters have a label, the filter name, arguments, and argument order are
compared. (Passing multiple filters is currently still possible, but
deprecated.)

`--vf-toggle=filter`

Add the given filter to the list if it was not present yet, or remove it
from the list if it was present. Matching of filters works as described in
`--vf-remove`.

`--vf-clr`

Completely empties the filter list.

With filters that support it, you can access parameters by their name.

`--vf=<filter>=help`

Prints the parameter names and parameter value ranges for a particular
filter.

Available mpv-only filters are:

`format=fmt=<value>:colormatrix=<value>:...`

Applies video parameter overrides, with optional conversion. By default,
this overrides the video's parameters without conversion (except for the
`fmt` parameter), but can be made to perform an appropriate conversion
with `convert=yes` for parameters for which conversion is supported.

`<fmt>`

Image format name, e.g. rgb15, bgr24, 420p, etc. (default: don't change).

This filter always performs conversion to the given format.

Note

For a list of available formats, use `--vf=format=fmt=help`.

Note

Conversion between hardware formats is supported in some cases.
eg: `cuda` to `vulkan`, or `vaapi` to `vulkan`.

`<convert=yes|no>`

Force conversion of color parameters (default: no).

If this is disabled (the default), the only conversion that is possibly
performed is format conversion if `<fmt>` is set. All other parameters
(like `<colormatrix>`) are forced without conversion. This mode is
typically useful when files have been incorrectly tagged.

If this is enabled, libswscale or zimg is used if any of the parameters
mismatch. zimg is used of the input/output image formats are supported
by mpv's zimg wrapper, and if `--sws-allow-zimg=yes` is used. Both
libraries may not support all kinds of conversions. This typically
results in silent incorrect conversion. zimg has in many cases a better
chance of performing the conversion correctly.

In both cases, the color parameters are set on the output stage of the
image format conversion (if `fmt` was set). The difference is that
with `convert=no`, the color parameters are not passed on to the
converter.

If input and output video parameters are the same, conversion is always
skipped.

When converting between hardware formats, this parameter has no effect,
and the only conversion that is done is the format conversion.

Examples

`mpv test.mkv --vf=format:colormatrix=ycgco`

Results in incorrect colors (if test.mkv was tagged correctly).

`mpv test.mkv --vf=format:colormatrix=ycgco:convert=yes --sws-allow-zimg`

Results in true conversion to `ycgco`, assuming the renderer
supports it (`--vo=gpu` normally does). You can add `--vo=xv`
