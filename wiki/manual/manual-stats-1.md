# STATS

This builtin script displays information and statistics for the currently
played file. It is enabled by default if mpv was compiled with Lua support.
It can be disabled entirely using the `--load-stats-overlay=no` option.

## Usage

The following key bindings are active by default unless something else is
already bound to them:
| i | Show stats for a fixed duration |
| --- | --- |
| I | Toggle stats (shown until toggled again) |
| ? | Toggle displaying the key bindings |

While the stats are visible on screen the following key bindings are active,
regardless of existing bindings. They allow you to switch between *pages* of
stats:
| 1 | Show usual stats |
| --- | --- |
| 2 | Show frame timings (scroll) |
| 3 | Input cache stats |
| 4 | Active key bindings (scroll) |
| 5 | Selected Tracks Info (scroll) |
| 0 | Internal stuff (scroll) |

If stats were displayed by toggling, these key bindings are also active:
| ESC | Close the stats |
| --- | --- |

On pages which support scroll, these key bindings are also active:
| UP | Scroll one line up |
| --- | --- |
| DOWN | Scroll one line down |

On page 4, these key bindings are also active:
| / | Search key bindings |
| --- | --- |

## Configuration

This script can be customized through a config file `script-opts/stats.conf`
placed in mpv's user directory and through the `--script-opts` command-line
option. The configuration syntax is described in [mp.options functions](manual-lua-scripting-1.md).

### Configurable Options

`key_page_1`

Default: 1

`key_page_2`

Default: 2

`key_page_3`

Default: 3

`key_page_4`

Default: 4

`key_page_5`

Default: 5

`key_page_0`

Default: 0

`key_exit`

Default: ESC

Key bindings for page switching while stats are displayed.

`key_scroll_up`

Default: UP

`key_scroll_down`

Default: DOWN

`key_scroll_search`

Default: /

`scroll_lines`

Default: 1

Scroll key bindings and number of lines to scroll on pages which support it.

`duration`

Default: 4

How long the stats are shown in seconds (oneshot).

`redraw_delay`

Default: 1

How long it takes to refresh the displayed stats in seconds (toggling).

`persistent_overlay`

Default: no

When <cite>no</cite>, other scripts printing text to the screen can overwrite the
displayed stats. When <cite>yes</cite>, displayed stats are persistently shown for the
respective duration. This can result in overlapping text when multiple
scripts decide to print text at the same time.

`file_tag_max_length`

Default: 128

Only show file tags shorter than this length, in bytes.

`file_tag_max_count`

Default: 16

Only show the first specified amount of file tags.

`term_clip`

Default: yes

Whether to clip lines to the terminal width.

`plot_perfdata`

Default: no

Show graphs for performance data (page 2).

`plot_vsync_ratio`

Default: no

`plot_vsync_jitter`

Default: no

Show graphs for vsync and jitter values (page 1). Only when toggled.

`plot_cache`

Default: yes

Show graphs for cache values (page 3). Only when toggled.

`plot_tonemapping_lut`

Default: no

Enable tone-mapping LUT visualization automatically. Only when toggled.

`flush_graph_data`

Default: yes

Clear data buffers used for drawing graphs when toggling.

`font`

Default: same as `osd-font`

Font name. Should support as many font weights as possible for optimal
visual experience.

`font_mono`

Default: monospace

Font name for parts where monospaced characters are necessary to align
text. Currently, monospaced digits are sufficient.

`font_size`

Default: 20

Font size used to render text.

`font_color`

Default: same as `osd-color`

Color of the text.

`border_size`
