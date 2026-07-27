Ignored if `tick_delay_follow_display_fps` is set to yes and the VO
supports the `display-fps` property.

`tick_delay_follow_display_fps`

Default: no

Use display fps to calculate the interval between OSC redraws.

The following options configure what commands are run when the buttons are
clicked. `mbtn_mid` commands are also triggered with `shift+mbtn_left`.

`menu_mbtn_left_command=script-binding select/menu; script-message-to osc osc-hide`

`menu_mbtn_mid_command=`

`menu_mbtn_right_command=`

`playlist_prev_mbtn_left_command=playlist-prev; show-text ${playlist} 3000`

`playlist_prev_mbtn_mid_command=show-text ${playlist} 3000`

`playlist_prev_mbtn_right_command=script-binding select/select-playlist; script-message-to osc osc-hide`

`playlist_next_mbtn_left_command=playlist-next; show-text ${playlist} 3000`

`playlist_next_mbtn_mid_command=show-text ${playlist} 3000`

`playlist_next_mbtn_right_command=script-binding select/select-playlist; script-message-to osc osc-hide`

`title_mbtn_left_command=script-binding stats/display-page-5`

`title_mbtn_mid_command=show-text ${path}`

`title_mbtn_right_command=script-binding select/select-watch-history; script-message-to osc osc-hide`

`play_pause_mbtn_left_command=cycle pause`

`play_pause_mbtn_mid_command=cycle-values loop-playlist inf no`

`play_pause_mbtn_right_command=cycle-values loop-file inf no`

`chapter_prev_mbtn_left_command=osd-msg add chapter -1`

`chapter_prev_mbtn_mid_command=show-text ${chapter-list} 3000`

`chapter_prev_mbtn_right_command=script-binding select/select-chapter; script-message-to osc osc-hide`

`chapter_next_mbtn_left_command=osd-msg add chapter 1`

`chapter_next_mbtn_mid_command=show-text ${chapter-list} 3000`

`chapter_next_mbtn_right_command=script-binding select/select-chapter; script-message-to osc osc-hide`

`audio_track_mbtn_left_command=cycle audio`

`audio_track_mbtn_mid_command=cycle audio down`

`audio_track_mbtn_right_command=script-binding select/select-aid; script-message-to osc osc-hide`

`audio_track_wheel_down_command=cycle audio`

`audio_track_wheel_up_command=cycle audio down`

`sub_track_mbtn_left_command=cycle sub`

`sub_track_mbtn_mid_command=cycle sub down`

`sub_track_mbtn_right_command=script-binding select/select-sid; script-message-to osc osc-hide`

`sub_track_wheel_down_command=cycle sub`

`sub_track_wheel_up_command=cycle sub down`

`volume_mbtn_left_command=no-osd cycle mute`

`volume_mbtn_mid_command=`

`volume_mbtn_right_command=script-binding select/select-audio-device; script-message-to osc osc-hide`

`volume_wheel_down_command=add volume -5`

`volume_wheel_up_command=add volume 5`

`fullscreen_mbtn_left_command="cycle fullscreen"`

`fullscreen_mbtn_mid_command=`

`fullscreen_mbtn_right_command="cycle window-maximized"`

### Custom Buttons

Additional script-opts are available to define custom buttons in `bottombar`
and `topbar` layouts.

Example to add loop, shuffle and speed buttons

```
custom_button_1_content=🔁
custom_button_1_mbtn_left_command=cycle-values loop-file inf no
custom_button_1_mbtn_right_command=cycle-values loop-playlist inf no

custom_button_2_content=🔀
custom_button_2_mbtn_left_command=playlist-shuffle

custom_button_3_content=⏱
custom_button_3_mbtn_left_command=add speed 1
custom_button_3_mbtn_right_command=set speed 1
custom_button_3_wheel_up_command=add speed 0.25
custom_button_3_wheel_down_command=add speed -0.25
```

### Script Commands

The OSC script listens to certain script commands. These commands can bound
in `input.conf`, or sent by other scripts.

`osc-visibility`

Controls visibility mode `never` / `auto` (on mouse move) / `always`
and also `cycle` to cycle between the modes. If a second argument is
passed (any value), then the output on the OSD will be silenced.

`osc-show`

Triggers the OSC to show up, just as if user moved mouse.

`osc-hide`

Hide the OSC when `visibility` is `auto`.

Example

You could put this into `input.conf` to hide the OSC with the `a` key and
to set auto mode (the default) with `b`:

```
a script-message osc-visibility never
b script-message osc-visibility auto
```

`osc-idlescreen`

Controls the visibility of the mpv logo on idle. Valid arguments are `yes`,
`no`, and `cycle` to toggle between yes and no. If a second argument is
passed (any value), then the output on the OSD will be silenced.
