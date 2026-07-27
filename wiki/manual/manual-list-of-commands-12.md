
Lua and possibly other backends treat this specially and may not pass the
actual event to the user.

The event has the following fields:

`args`

Array of strings with the message data.

`video-reconfig` (`MPV_EVENT_VIDEO_RECONFIG`)

Happens on video output or filter reconfig.

`audio-reconfig` (`MPV_EVENT_AUDIO_RECONFIG`)

Happens on audio output or filter reconfig.

`property-change` (`MPV_EVENT_PROPERTY_CHANGE`)

Happens when a property that is being observed changes value.

The event has the following fields:

`name`

The name of the property.

`data`

The new value of the property.

The following events also happen, but are deprecated: `idle`, `tick`
Use `mpv_observe_property()` (Lua: `mp.observe_property()`) instead.
