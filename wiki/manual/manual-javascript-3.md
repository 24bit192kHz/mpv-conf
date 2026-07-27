## The event loop

The event loop poll/dispatch mpv events as long as the queue is not empty, then
processes the timers, then waits for the next event, and repeats this forever.

You could put this code at your script to replace the built-in event loop, and
also print every event which mpv sends to your script:

```
function mp_event_loop() {
    var wait = 0;
    do {
        var e = mp.wait_event(wait);
        dump(e);  // there could be a lot of prints...
        if (e.event != "none") {
            mp.dispatch_event(e);
            wait = 0;
        } else {
            wait = mp.process_timers() / 1000;
            if (wait != 0) {
                mp.notify_idle_observers();
                wait = mp.peek_timers_wait() / 1000;
            }
        }
    } while (mp.keep_running);
}
```

`mp_event_loop` is a name which mpv tries to call after the script loads.
The internal implementation is similar to this (without `dump` though..).

`e = mp.wait_event(wait)` returns when the next mpv event arrives, or after
`wait` seconds if positive and no mpv events arrived. `wait` value of 0
returns immediately (with `e.event == "none"` if the queue is empty).

`mp.dispatch_event(e)` calls back the handlers registered for `e.event`,
if there are such (event handlers, property observers, script messages, etc).

`mp.process_timers()` calls back the already-added, non-canceled due timers,
and returns the duration in ms till the next due timer (possibly 0), or -1 if
there are no pending timers. Must not be called recursively.

`mp.notify_idle_observers()` calls back the idle observers, which we do when
we're about to sleep (wait != 0), but the observers may add timers or take
non-negligible duration to complete, so we re-calculate `wait` afterwards.

`mp.peek_timers_wait()` returns the same values as `mp.process_timers()`
but without doing anything. Invalid result if called from a timer callback.

Note: `exit()` is also registered for the `shutdown` event, and its
implementation is a simple `mp.keep_running = false`.
