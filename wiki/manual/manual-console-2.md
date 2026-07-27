### Configurable Options

`monospace_font`

Default: platform dependent

The monospace font used when there are completions to align in a grid.

When there are no completions, `--osd-font` is used.

`font_size`

Default: 24

The font size. This will be multiplied by `display-hidpi-scale` when the
console is not scaled with the window.

`border_size`

Default: 1.65

The font border size.

`background_alpha`

Default: 80

The transparency of the menu's background. Ranges from 0 (opaque) to 255
(fully transparent).

`gap`

Default: 0.2

The gap between menu items, specified as a percentage the font size.

`padding`

Default: 10

The padding of the menu.

`menu_outline_size`

Default: 0

The size of the menu's border.

`menu_outline_color`

Default: #FFFFFF

The color of the menu's border.

`corner_radius`

Default: 8

The radius of the menu's corners.

`margin_x`

Default: same as `--osd-margin-x`

The margin from the left of the window.

`margin_y`

Default: same as `--osd-margin-y`

The margin from the bottom of the window.

`scale_with_window`

Default: `auto`

Whether to scale the console with the window height. Can be `yes`, `no`,
or `auto`, which follows the value of `--osd-scale-by-window`.

`focused_color`

Default: `#222222`

The color of the focused item.

`focused_back_color`

Default: `#FFFFFF`

The background color of the focused item.

`match_color`

Default: `#0088FF`

The color of characters that match the searched string.

`exact_match`

Default: no

Whether to match menu search queries exactly instead of fuzzily. Without
this option, prefixing queries with `'` enables exact matching.

`case_sensitive`

Default: no

Whether exact searches are case sensitive. Only works with ASCII characters.

`history_dedup`

Default: true

Remove duplicate entries in history as to only keep the latest one.

`font_hw_ratio`

Default: auto

The ratio of font height to font width.
Adjusts grid width of completions.
Values in the range 1.8..2.5 make sense for common monospace fonts.
