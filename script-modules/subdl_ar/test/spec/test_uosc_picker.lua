-- Spec: UOSC subtitle picker menu generation.
--
-- The picker module formats a subtitle list into uosc's menu-open JSON
-- structure. Each item shows release_name, lang, and score. The item's
-- value triggers script-message subdl_ar_download_item <index>.

local H = require "harness"

local picker = require "subdl_ar.ui.uosc_picker"

---------------------------------------------------------------------------
-- build_menu: basic structure.
---------------------------------------------------------------------------
do
  H.reset()
  local subs = {
    { release_name = "Show.S01E01.WEB.x264", lang = "ar", score = 9500 },
    { release_name = "Show.S01E01.HDTV", lang = "ar", score = 5000 },
  }
  local menu = picker.build_menu(subs)

  H.ok("menu has title", type(menu.title) == "string" and #menu.title > 0)
  H.ok("menu has items table", type(menu.items) == "table")
  H.eq("menu items count", #menu.items, 2)
end

---------------------------------------------------------------------------
-- build_menu: item fields.
---------------------------------------------------------------------------
do
  H.reset()
  local subs = {
    { release_name = "Show.S01E01.WEB.x264", lang = "ar", score = 9500 },
  }
  local menu = picker.build_menu(subs)
  local item = menu.items[1]

  H.ok("item has title field", type(item.title) == "string" and #item.title > 0)
  H.ok("item title contains release_name",
       item.title:find("Show.S01E01.WEB.x264", 1, true) ~= nil)
  H.ok("item title contains lang",
       item.title:find("ar", 1, true) ~= nil)
  H.ok("item title contains score",
       item.title:find("9500", 1, true) ~= nil)
end

---------------------------------------------------------------------------
-- build_menu: item value is download command.
---------------------------------------------------------------------------
do
  H.reset()
  local subs = {
    { release_name = "Show.S01E01.WEB.x264", lang = "ar", score = 9500 },
    { release_name = "Show.S01E01.HDTV", lang = "ar", score = 5000 },
  }
  local menu = picker.build_menu(subs)

  H.eq("item 1 value command",
       menu.items[1].value,
       "script-message subdl_ar_download_item 1")
  H.eq("item 2 value command",
       menu.items[2].value,
       "script-message subdl_ar_download_item 2")
end

---------------------------------------------------------------------------
-- build_menu: empty list → empty items.
---------------------------------------------------------------------------
do
  H.reset()
  local menu = picker.build_menu({})
  H.eq("empty subs → 0 items", #menu.items, 0)
end

---------------------------------------------------------------------------
-- build_menu: nil list → empty items.
---------------------------------------------------------------------------
do
  H.reset()
  local menu = picker.build_menu(nil)
  H.eq("nil subs → 0 items", #menu.items, 0)
end

---------------------------------------------------------------------------
-- build_menu: multiple subs sorted by score descending.
---------------------------------------------------------------------------
do
  H.reset()
  local subs = {
    { release_name = "B.HDTV", lang = "ar", score = 1000 },
    { release_name = "A.WEB", lang = "ar", score = 9000 },
    { release_name = "C.DVD", lang = "ar", score = 500 },
  }
  local menu = picker.build_menu(subs)

  H.ok("first item is highest score",
       menu.items[1].title:find("A.WEB", 1, true) ~= nil)
  H.ok("second item is mid score",
       menu.items[2].title:find("B.HDTV", 1, true) ~= nil)
  H.ok("third item is lowest score",
       menu.items[3].title:find("C.DVD", 1, true) ~= nil)
end

---------------------------------------------------------------------------
-- format_item: missing fields handled gracefully.
---------------------------------------------------------------------------
do
  H.reset()
  local item = picker.format_item({ release_name = "Test", lang = "ar" }, 1)
  H.ok("item without score still has title",
       type(item.title) == "string" and #item.title > 0)
  H.ok("item title has N/A for missing score",
       item.title:find("N/A", 1, true) ~= nil)
end

---------------------------------------------------------------------------
-- format_item: nil release_name.
---------------------------------------------------------------------------
do
  H.reset()
  local item = picker.format_item({ lang = "ar", score = 100 }, 1)
  H.ok("nil release_name → Unknown in title",
       item.title:find("Unknown", 1, true) ~= nil)
end
