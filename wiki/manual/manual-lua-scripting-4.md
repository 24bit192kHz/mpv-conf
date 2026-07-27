`none` is the same as `nil`. For all other values, the new value of
the property will be passed as second argument to `fn`, using
`mp.get_property_<type>` to retrieve it. This means if `type` is for
example `string`, `fn` is roughly called as in
`fn(name, mp.get_property(name))`.

If possible, change events are coalesced. If a property is changed a bunch
of times in a row, only the last change triggers the change function. (The
exact behavior depends on timing and other things.)

If a property is unavailable, or on error, the value argument to `fn` is
`nil`. (The `observe_property()` call always succeeds, even if a
property does not exist.)

In some cases the function is not called even if the property changes.
This depends on the property, and it's a valid feature request to ask for
better update handling of a specific property.

If the `type` is `none` or `nil`, the change function `fn` will be
called sporadically even if the property doesn't actually change. You should
therefore avoid using these types.

You always get an initial change notification. This is meant to initialize
the user's state to the current value of the property.

`mp.unobserve_property(fn)`

Undo `mp.observe_property(..., fn)`. This removes all property handlers
that are equal to the `fn` parameter. This uses normal Lua `==`
comparison, so be careful when dealing with closures.

`mp.add_timeout(seconds, fn [, disabled])`

Call the given function fn when the given number of seconds has elapsed.
Note that the number of seconds can be fractional. For now, the timer's
resolution may be as low as 50 ms, although this will be improved in the
future.

If the `disabled` argument is set to `true` or a truthy value, the
timer will wait to be manually started with a call to its `resume()`
method.

This is a one-shot timer: it will be removed when it's fired.

Returns a timer object. See `mp.add_periodic_timer` for details.

`mp.add_periodic_timer(seconds, fn [, disabled])`

Call the given function periodically. This is like `mp.add_timeout`, but
the timer is re-added after the function fn is run.

Returns a timer object. The timer object provides the following methods:

> `stop()`
>
>
> Disable the timer. Does nothing if the timer is already disabled.
> This will remember the current elapsed time when stopping, so that
> `resume()` essentially unpauses the timer.
>
>
> `kill()`
>
>
> Disable the timer. Resets the elapsed time. `resume()` will
> restart the timer.
>
>
> `resume()`
>
>
> Restart the timer. If the timer was disabled with `stop()`, this
> will resume at the time it was stopped. If the timer was disabled
> with `kill()`, or if it's a previously fired one-shot timer (added
> with `add_timeout()`), this starts the timer from the beginning,
> using the initially configured timeout.
>
>
> `is_enabled()`
>
>
> Whether the timer is currently enabled or was previously disabled
> (e.g. by `stop()` or `kill()`).
>
>
> `timeout` (RW)
>
>
>
>
> This field contains the current timeout period. This value is not
> updated as time progresses. It's only used to calculate when the
> timer should fire next when the timer expires.
>
>
> If you write this, you can call `t:kill() ; t:resume()` to reset
> the current timeout to the new one. (`t:stop()` won't use the
> new timeout.)
>
>
> `oneshot` (RW)
>
>
> Whether the timer is periodic (`false`) or fires just once
> (`true`). This value is used when the timer expires (but before
> the timer callback function fn is run).

Note that these are methods, and you have to call them using `:` instead
of `.` (Refer to [https://www.lua.org/manual/5.2/manual.html#3.4.9](https://www.lua.org/manual/5.2/manual.html#3.4.9) .)

Example:

```
seconds = 0
timer = mp.add_periodic_timer(1, function()
    print("called every second")
    -- stop it after 10 seconds
    seconds = seconds + 1
    if seconds >= 10 then
        timer:kill()
    end
end)
```

`mp.get_opt(key)`

Return a setting from the `--script-opts` option. It's up to the user and
the script how this mechanism is used. Currently, all scripts can access
this equally, so you should be careful about collisions.

`mp.get_script_name()`

Return the name of the current script. The name is usually made of the
filename of the script, with directory and file extension removed. If
there are several scripts which would have the same name, it's made unique
by appending a number. Any nonalphanumeric characters are replaced with `_`.

Example

The script `/path/to/foo-script.lua` becomes `foo_script`.

`mp.get_script_directory()`

Return the directory if this is a script packaged as directory (see
[Script location](manual-lua-scripting-1.md) for a description). Return nothing if this is a single
file script.

`mp.osd_message(text [,duration])`

Show an OSD message on the screen. `duration` is in seconds, and is
optional (uses `--osd-duration` by default).

