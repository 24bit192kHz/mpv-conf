## Properties

Properties are used to set mpv options during runtime, or to query arbitrary
information. They can be manipulated with the `set`/`add`/`cycle`
commands, and retrieved with `show-text`, or anything else that uses property
expansion. (See [Property Expansion](manual-property-list-1.md).)

If an option is referenced, the property will normally take/return exactly the
same values as the option. In these cases, properties are merely a way to change
an option at runtime.

Note that many properties are unavailable at startup. See [Details on the script
initialization and lifecycle](manual-lua-scripting-1.md).
