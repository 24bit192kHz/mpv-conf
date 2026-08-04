-- keylayout.lua
--
-- Dependency-free fallback shortcut translator for mpv.
--
-- What this script CAN do:
--   * Translate known non-ASCII characters back to English/QWERTY key equivalents.
--   * Restore Arabic base letters plus shifted/diacritic forms.
--   * Provide safe built-in tables for a few common scripts/layouts.
--   * Load user-defined mappings from plain map files inside mpv's config tree.
--
-- What this script CANNOT honestly promise:
--   * Full support for every keyboard on Earth.
--   * Correct handling of all dead keys, IMEs, compose keys, or platform input methods.
--   * Fixing X11/XWayland cases where mpv drops non-ASCII keys before scripts see them.
--   * Safe automatic physical-key remapping for AZERTY/QWERTZ/Dvorak/Spanish/French/etc.
--     unless you explicitly accept the risk of binding ASCII characters.
--
-- Options file:
--   script-opts/keylayout.conf
--
-- Example options:
--   debug=no
--   enabled=yes
--   modifiers=yes
--   osd=no
--   groups=default
--   layout=
--   custom_file=
--   allow_ascii_source=no
--
-- Built-in groups:
--   arabic          default
--   russian         default
--   greek           default
--   arabic_digits   optional, disabled by default
--   spanish         optional, disabled by default
--
-- Group syntax:
--   groups=default              use default groups
--   groups=all                  use all built-in groups
--   groups=none                 use no built-in groups
--   groups=arabic,spanish       use only listed groups
--
-- Spanish note:
--   The spanish group is disabled by default because mapping ñ/Ñ can hijack
--   actual typing of those characters in mpv console/search. Enable it only
--   if you do not need to type ñ/Ñ inside mpv.
--
-- Custom mapping files:
--   script-opts/keylayout.map
--   script-opts/keylayout.custom
--   script-opts/keymaps/default.map
--   script-opts/keymaps/<layout>.map   when layout=<layout>
--
-- Custom mapping format:
--   source_char=target_key
--
-- Example:
--   ñ=;
--   Ñ=:
--
-- Important:
--   Do not put custom char=key mappings in keylayout.conf. That file is for
--   mpv script options. This script intentionally reads mappings from separate
--   .map files.

local mp = require "mp"
local options = require "mp.options"

local opts = {
    debug = false,
    enabled = true,
    modifiers = true,
    osd = false,

    -- default | all | none | comma-separated group names
    groups = "default",

    -- Comma-separated layout names.
    -- For each name, the script tries:
    --   script-opts/keymaps/<name>.map
    layout = "",

    -- Optional extra custom mapping file path, relative to mpv config.
    -- Must not contain traversal, absolute paths, colons, backslashes, or ~.
    custom_file = "",

    -- Dangerous. If enabled, ASCII characters can be used as source keys.
    -- This may break normal typing/console/search behavior.
    allow_ascii_source = false,
}

options.read_options(opts, "keylayout")

local function log(...)
    if opts.debug then
        mp.msg.log("debug", ...)
    end
end

if not opts.enabled then
    mp.msg.info("keylayout disabled by option")
    return
end

if opts.allow_ascii_source then
    mp.msg.warn("allow_ascii_source is enabled; ASCII source keys may be hijacked.")
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function is_ascii(s)
    if type(s) ~= "string" then
        return false
    end

    for i = 1, #s do
        if s:byte(i) > 127 then
            return false
        end
    end

    return true
end

local function contains_control(s)
    if type(s) ~= "string" then
        return true
    end

    if s:find("\0", 1, true) then
        return true
    end

    return s:find("[%c]") ~= nil
end

local function split_csv(s)
    local out = {}

    if type(s) ~= "string" or s == "" then
        return out
    end

    for item in s:gmatch("[^,]+") do
        item = item:match("^%s*(.-)%s*$")
        if item ~= "" then
            out[#out + 1] = item
        end
    end

    return out
end

---------------------------------------------------------------------------
-- Built-in tables
---------------------------------------------------------------------------

local GROUPS = {
    -----------------------------------------------------------------------
    -- Arabic: base letters + shifted/diacritic forms
    -- Verified against /usr/share/X11/xkb/symbols/ara
    -----------------------------------------------------------------------
    arabic = {
        -- Base letters
        ["ض"] = "q",
        ["ص"] = "w",
        ["ث"] = "e",
        ["ق"] = "r",
        ["ف"] = "t",
        ["غ"] = "y",
        ["ع"] = "u",
        ["ه"] = "i",
        ["خ"] = "o",
        ["ح"] = "p",
        ["ج"] = "[",
        ["د"] = "]",

        ["ش"] = "a",
        ["س"] = "s",
        ["ي"] = "d",
        ["ب"] = "f",
        ["ل"] = "g",
        ["ا"] = "h",
        ["ت"] = "j",
        ["ن"] = "k",
        ["م"] = "l",
        ["ك"] = ";",
        ["ط"] = "'",

        ["ئ"] = "z",
        ["ء"] = "x",
        ["ؤ"] = "c",
        ["ر"] = "v",
        ["ﻻ"] = "b",
        ["ى"] = "n",
        ["ة"] = "m",
        ["و"] = ",",
        ["ز"] = ".",
        ["ظ"] = "/",

        -- Shifted forms / diacritics / punctuation
        ["َ"] = "Q", -- fatha
        ["ً"] = "W", -- tanwin fath
        ["ُ"] = "E", -- damma
        ["ٌ"] = "R", -- tanwin damm
        ["ﻹ"] = "T",
        ["إ"] = "Y",
        ["÷"] = "I",
        ["×"] = "O",
        ["؛"] = "P", -- Arabic semicolon
        ["ِ"] = "A", -- kasra
        ["ٍ"] = "S", -- tanwin kasr
        ["ﻷ"] = "G",
        ["أ"] = "H",
        ["ـ"] = "J", -- tatweel
        ["،"] = "K", -- Arabic comma
        ["ْ"] = "X", -- sukun
        ["ﻵ"] = "B",
        ["آ"] = "N",
        ["؟"] = "?", -- Arabic question mark
        ["ذ"] = "`",
    },

    -----------------------------------------------------------------------
    -- Arabic-Indic digits
    --
    -- Optional. Disabled by default because it hijacks typing of Arabic
    -- digits in mpv console/search.
    -----------------------------------------------------------------------
    arabic_digits = {
        ["٠"] = "0",
        ["١"] = "1",
        ["٢"] = "2",
        ["٣"] = "3",
        ["٤"] = "4",
        ["٥"] = "5",
        ["٦"] = "6",
        ["٧"] = "7",
        ["٨"] = "8",
        ["٩"] = "9",

        -- Extended Arabic-Indic digits, used by Persian/Urdu and others
        ["۰"] = "0",
        ["۱"] = "1",
        ["۲"] = "2",
        ["۳"] = "3",
        ["۴"] = "4",
        ["۵"] = "5",
        ["۶"] = "6",
        ["۷"] = "7",
        ["۸"] = "8",
        ["۹"] = "9",
    },

    -----------------------------------------------------------------------
    -- Russian / Cyrillic
    -- Verified against /usr/share/X11/xkb/symbols/ru
    -----------------------------------------------------------------------
    russian = {
        ["й"] = "q",
        ["ц"] = "w",
        ["у"] = "e",
        ["к"] = "r",
        ["е"] = "t",
        ["н"] = "y",
        ["г"] = "u",
        ["ш"] = "i",
        ["щ"] = "o",
        ["з"] = "p",
        ["х"] = "[",
        ["ъ"] = "]",

        ["ф"] = "a",
        ["ы"] = "s",
        ["в"] = "d",
        ["а"] = "f",
        ["п"] = "g",
        ["р"] = "h",
        ["о"] = "j",
        ["л"] = "k",
        ["д"] = "l",
        ["ж"] = ";",
        ["э"] = "'",

        ["я"] = "z",
        ["ч"] = "x",
        ["с"] = "c",
        ["м"] = "v",
        ["и"] = "b",
        ["т"] = "n",
        ["ь"] = "m",
        ["б"] = ",",
        ["ю"] = ".",
        ["ё"] = "`",
    },

    -----------------------------------------------------------------------
    -- Greek
    -- Letters only, avoiding ASCII lookalikes/punctuation.
    -- Verified against /usr/share/X11/xkb/symbols/gr
    -----------------------------------------------------------------------
    greek = {
        ["ς"] = "w",
        ["ε"] = "e",
        ["ρ"] = "r",
        ["τ"] = "t",
        ["υ"] = "y",
        ["θ"] = "u",
        ["ι"] = "i",
        ["ο"] = "o",
        ["π"] = "p",

        ["α"] = "a",
        ["σ"] = "s",
        ["δ"] = "d",
        ["φ"] = "f",
        ["γ"] = "g",
        ["η"] = "h",
        ["ξ"] = "j",
        ["κ"] = "k",
        ["λ"] = "l",

        ["ζ"] = "z",
        ["χ"] = "x",
        ["ψ"] = "c",
        ["ω"] = "v",
        ["β"] = "b",
        ["ν"] = "n",
        ["μ"] = "m",
    },

    -----------------------------------------------------------------------
    -- Spanish, minimal support
    --
    -- Disabled by default.
    --
    -- This group hijacks typing of ñ/Ñ inside mpv. Enable it only if you
    -- never need to type those characters in mpv console/search.
    -----------------------------------------------------------------------
    spanish = {
        ["ñ"] = ";",
        ["Ñ"] = ":",
    },

    -----------------------------------------------------------------------
    -- Generated from system xkb data (verified against
    -- /usr/share/X11/xkb/symbols/*). Letters only; no punctuation/ASCII.
    -- Phonetic/QWERTY-deterministic variants.
    -----------------------------------------------------------------------
armenian_phonetic = {
        ["ա"] = "a",
        ["բ"] = "b",
        ["գ"] = "g",
        ["դ"] = "d",
        ["ե"] = "e",
        ["զ"] = "z",
        ["ը"] = "y",
        ["ժ"] = "z",
        ["ի"] = "i",
        ["լ"] = "l",
        ["խ"] = "[",
        ["ծ"] = "]",
        ["կ"] = "k",
        ["հ"] = "h",
        ["ղ"] = "x",
        ["ճ"] = "q",
        ["մ"] = "m",
        ["յ"] = "j",
        ["ն"] = "n",
        ["ո"] = "w",
        ["պ"] = "p",
        ["ջ"] = "a",
        ["ս"] = "s",
        ["վ"] = "v",
        ["տ"] = "t",
        ["ր"] = "r",
        ["ց"] = "c",
        ["ւ"] = "u",
        ["փ"] = "w",
        ["ք"] = "q",
        ["օ"] = "o",
        ["ֆ"] = "f",
    },

    georgian_qwerty = {
        ["ა"] = "a",
        ["ბ"] = "b",
        ["გ"] = "g",
        ["დ"] = "d",
        ["ე"] = "e",
        ["ვ"] = "v",
        ["ზ"] = "z",
        ["ი"] = "i",
        ["კ"] = "k",
        ["ლ"] = "l",
        ["მ"] = "m",
        ["ნ"] = "n",
        ["ო"] = "o",
        ["პ"] = "p",
        ["რ"] = "r",
        ["ს"] = "s",
        ["ტ"] = "t",
        ["უ"] = "u",
        ["ფ"] = "f",
        ["ქ"] = "q",
        ["ყ"] = "y",
        ["ც"] = "c",
        ["წ"] = "w",
        ["ხ"] = "x",
        ["ჯ"] = "j",
        ["ჰ"] = "h",
    },

    bulgarian_phonetic = {
        ["а"] = "a",
        ["б"] = "b",
        ["в"] = "w",
        ["г"] = "g",
        ["д"] = "d",
        ["е"] = "e",
        ["ж"] = "v",
        ["з"] = "z",
        ["и"] = "i",
        ["й"] = "j",
        ["к"] = "k",
        ["л"] = "l",
        ["м"] = "m",
        ["н"] = "n",
        ["о"] = "o",
        ["п"] = "p",
        ["р"] = "r",
        ["с"] = "s",
        ["т"] = "t",
        ["у"] = "u",
        ["ф"] = "f",
        ["х"] = "h",
        ["ц"] = "c",
        ["ч"] = "`",
        ["ш"] = "[",
        ["щ"] = "]",
        ["ъ"] = "y",
        ["ь"] = "x",
        ["я"] = "q",
    },

    bulgarian_bas_phonetic = {
        ["а"] = "a",
        ["б"] = "b",
        ["в"] = "v",
        ["г"] = "g",
        ["д"] = "d",
        ["е"] = "e",
        ["ж"] = "x",
        ["з"] = "z",
        ["и"] = "i",
        ["й"] = "j",
        ["к"] = "k",
        ["л"] = "l",
        ["м"] = "m",
        ["н"] = "n",
        ["о"] = "o",
        ["п"] = "p",
        ["р"] = "r",
        ["с"] = "s",
        ["т"] = "t",
        ["у"] = "u",
        ["ф"] = "f",
        ["х"] = "h",
        ["ц"] = "c",
        ["ч"] = "q",
        ["ш"] = "w",
        ["щ"] = "]",
        ["ъ"] = "y",
        ["ю"] = "`",
        ["я"] = "[",
    },

    belarusian_phonetic = {
        ["а"] = "a",
        ["б"] = "b",
        ["в"] = "w",
        ["г"] = "g",
        ["д"] = "d",
        ["е"] = "e",
        ["ж"] = "v",
        ["з"] = "z",
        ["й"] = "j",
        ["к"] = "k",
        ["л"] = "l",
        ["м"] = "m",
        ["н"] = "n",
        ["о"] = "o",
        ["п"] = "p",
        ["р"] = "r",
        ["с"] = "s",
        ["т"] = "t",
        ["у"] = "u",
        ["ф"] = "f",
        ["х"] = "h",
        ["ц"] = "c",
        ["ш"] = "[",
        ["ы"] = "y",
        ["ь"] = "x",
        ["ю"] = "`",
        ["я"] = "q",
        ["і"] = "i",
        ["ў"] = "]",
    },

    macedonian = {
        ["а"] = "a",
        ["б"] = "b",
        ["в"] = "v",
        ["г"] = "g",
        ["д"] = "d",
        ["е"] = "e",
        ["з"] = "z",
        ["и"] = "i",
        ["к"] = "k",
        ["л"] = "l",
        ["м"] = "m",
        ["н"] = "n",
        ["о"] = "o",
        ["п"] = "p",
        ["р"] = "r",
        ["с"] = "s",
        ["т"] = "t",
        ["у"] = "u",
        ["ф"] = "f",
        ["х"] = "h",
        ["ц"] = "c",
        ["ч"] = ";",
        ["ш"] = "[",
        ["ѓ"] = "]",
        ["ѕ"] = "y",
        ["ј"] = "j",
        ["љ"] = "q",
        ["њ"] = "w",
        ["ќ"] = "'",
        ["џ"] = "x",
    },

    mongolian = {
        ["а"] = "g",
        ["б"] = "d",
        ["в"] = ".",
        ["г"] = "u",
        ["д"] = ";",
        ["ж"] = "r",
        ["з"] = "p",
        ["и"] = "n",
        ["й"] = "a",
        ["к"] = "[",
        ["л"] = "l",
        ["м"] = "b",
        ["н"] = "y",
        ["о"] = "k",
        ["п"] = "'",
        ["р"] = "j",
        ["с"] = "v",
        ["т"] = "m",
        ["у"] = "e",
        ["ф"] = "q",
        ["х"] = "h",
        ["ц"] = "w",
        ["ч"] = "x",
        ["ш"] = "i",
        ["ъ"] = "]",
        ["ы"] = "s",
        ["ь"] = ",",
        ["э"] = "t",
        ["ю"] = "/",
        ["я"] = "z",
        ["ё"] = "c",
        ["ү"] = "o",
        ["ө"] = "f",
    },
}

local DEFAULT_GROUPS = {
    "arabic",
    "russian",
    "greek",
}

local GROUP_ORDER = {
    "arabic",
    "arabic_digits",
    "russian",
    "greek",
    "spanish",
    "armenian_phonetic",
    "georgian_qwerty",
    "bulgarian_phonetic",
    "bulgarian_bas_phonetic",
    "belarusian_phonetic",
    "macedonian",
    "mongolian",
}

---------------------------------------------------------------------------
-- Mapping state and validation
---------------------------------------------------------------------------

local final_map = {}

local function valid_source(ch)
    if type(ch) ~= "string" or ch == "" then
        return false
    end

    if contains_control(ch) then
        return false
    end

    if ch:find("%s") then
        return false
    end

    if is_ascii(ch) then
        return opts.allow_ascii_source
    end

    return true
end

local function valid_target(key)
    if type(key) ~= "string" or key == "" then
        return false
    end

    if not is_ascii(key) then
        return false
    end

    if contains_control(key) then
        return false
    end

    if key:find("%s") then
        return false
    end

    if key:find("=", 1, true) then
        return false
    end

    return true
end

local function add_final_mapping(ch, key)
    if not valid_source(ch) then
        log("skipping invalid source: " .. ch)
        return false
    end

    if not valid_target(key) then
        log("skipping invalid target for source " .. ch .. ": " .. key)
        return false
    end

    final_map[ch] = key
    return true
end

---------------------------------------------------------------------------
-- Path safety
---------------------------------------------------------------------------

local function safe_relative_path(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    if path:find("\0", 1, true) then
        return nil
    end

    -- Reject absolute POSIX paths.
    if path:match("^/") then
        return nil
    end

    -- Reject home expansion and anything containing tilde.
    if path:find("~", 1, true) then
        return nil
    end

    -- Reject Windows-style drives and alternate stream syntax.
    if path:find(":", 1, true) then
        return nil
    end

    -- Reject Windows separators. Config-relative paths should use /.
    if path:find("\\", 1, true) then
        return nil
    end

    -- Reject traversal components.
    for part in path:gmatch("[^/]+") do
        if part == "." or part == ".." then
            return nil
        end
    end

    return path
end

---------------------------------------------------------------------------
-- Built-in group selection
---------------------------------------------------------------------------

local function get_selected_group_names()
    local value = tostring(opts.groups or "default"):lower()
    value = value:match("^%s*(.-)%s*$") or ""

    if value == "" or value == "default" then
        return DEFAULT_GROUPS
    end

    if value == "all" then
        return GROUP_ORDER
    end

    if value == "none" then
        return {}
    end

    local names = {}
    local seen = {}

    for _, item in ipairs(split_csv(value)) do
        item = item:lower()

        if GROUPS[item] then
            if not seen[item] then
                names[#names + 1] = item
                seen[item] = true
            end
        else
            mp.msg.warn("keylayout: unknown group: " .. item)
        end
    end

    return names
end

local function apply_builtin_groups()
    for _, name in ipairs(get_selected_group_names()) do
        local count = 0

        for ch, key in pairs(GROUPS[name]) do
            if add_final_mapping(ch, key) then
                count = count + 1
            end
        end

        log("loaded builtin group: " .. name .. " (" .. count .. " entries)")
    end
end

---------------------------------------------------------------------------
-- User map files
---------------------------------------------------------------------------

local function load_map_file(relpath, label)
    local safe = safe_relative_path(relpath)
    if not safe then
        mp.msg.warn("keylayout: rejected unsafe path for " .. label .. ": " .. tostring(relpath))
        return 0
    end

    local resolved = mp.find_config_file(safe)
    if not resolved then
        log("map file not found: " .. safe)
        return 0
    end

    local f = io.open(resolved, "r")
    if not f then
        log("map file not readable: " .. resolved)
        return 0
    end

    local count = 0
    local first_line = true

    for line in f:lines() do
        if first_line then
            -- Strip UTF-8 BOM if present.
            line = line:gsub("^\239\187\191", "")
            first_line = false
        end

        -- Normalize Windows line endings.
        line = line:gsub("\r$", "")

        -- Strip comments.
        line = line:gsub("#.*$", "")

        if line:match("%S") then
            local ch, key = line:match("^%s*([^=]-)%s*=%s*(.-)%s*$")

            if ch and key then
                if add_final_mapping(ch, key) then
                    count = count + 1
                    log(label .. ": " .. ch .. " -> " .. key)
                end
            end
        end
    end

    f:close()

    if count > 0 then
        mp.msg.info("keylayout: loaded " .. count .. " mappings from " .. label)
    end

    return count
end

local function load_user_maps()
    -- General custom maps.
    load_map_file("script-opts/keylayout.map", "script-opts/keylayout.map")
    load_map_file("script-opts/keylayout.custom", "script-opts/keylayout.custom")

    -- Optional default keymap.
    load_map_file("script-opts/keymaps/default.map", "script-opts/keymaps/default.map")

    -- Optional layout-specific keymaps.
    for _, name in ipairs(split_csv(opts.layout)) do
        if name:match("^[A-Za-z0-9_%-]+$") then
            load_map_file("script-opts/keymaps/" .. name .. ".map", "script-opts/keymaps/" .. name .. ".map")
        else
            mp.msg.warn("keylayout: unsafe or invalid layout name ignored: " .. name)
        end
    end

    -- Optional extra custom file from options.
    if tostring(opts.custom_file or "") ~= "" then
        load_map_file(opts.custom_file, "custom_file")
    end
end

---------------------------------------------------------------------------
-- Binding installation
---------------------------------------------------------------------------

local function install_bindings()
    local count = 0

    for source, target in pairs(final_map) do
        if valid_source(source) and valid_target(target) and source ~= target then
            -- CRITICAL:
            -- Pass nil as binding name so mpv auto-generates an ASCII name.
            -- Non-ASCII binding names are silently dropped by mpv.
            mp.add_forced_key_binding(source, nil, function()
                log("binding fired: " .. source .. " -> keypress " .. target)
                mp.commandv("keypress", target)
            end, { repeatable = false })

            -- Add modifier variants only for simple alphanumeric targets.
            -- This avoids dubious combos for punctuation and keeps the count sane.
            if opts.modifiers and target:match("^[%a%d]$") then
                for _, mod in ipairs({"ctrl", "alt"}) do
                    mp.add_forced_key_binding(mod .. "+" .. source, nil, function()
                        mp.commandv("keypress", mod .. "+" .. target)
                    end, { repeatable = false })
                end
            end

            count = count + 1
        end
    end

    if count > 0 then
        mp.msg.info("keylayout: installed " .. count .. " fallback mappings")

        if opts.osd then
            mp.osd_message("keylayout: installed " .. count .. " fallback mappings", 2)
        end
    else
        mp.msg.warn("keylayout: no mappings installed")

        if opts.osd then
            mp.osd_message("keylayout: no mappings installed", 2)
        end
    end
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

apply_builtin_groups()
load_user_maps()
install_bindings()
