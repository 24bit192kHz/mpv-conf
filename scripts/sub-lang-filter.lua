-- sub-lang-filter: keep only subtitles in the allow-list visible to
-- selection and cycling: Arabic + English + the source language (the
-- first audio track's language). Embedded tracks can't be removed from
-- mpv's track list, so "hide" = never selected, never cycled to.
-- External tracks (ar_subs fetches, manual loads) are always allowed.

local mp = require "mp"
local options = require "mp.options"

local opts = {
    -- fixed allowed languages on top of the source language
    languages = "ar,ara,arabic,en,eng,english",
    -- re-select an allowed track if the current one is outside the allow-list
    enforce = true,
}
options.read_options(opts, "sub_lang_filter")

-- ISO 639 alias groups: matching any member allows all members.
local alias_groups = {
    {"ar", "ara", "arabic"},
    {"en", "eng", "english"},
    {"ja", "jpn", "jap", "japanese"},
    {"pt", "por", "portuguese"},
    {"es", "spa", "spanish"},
    {"fr", "fra", "fre", "french"},
    {"de", "deu", "ger", "german"},
    {"it", "ita", "italian"},
    {"ru", "rus", "russian"},
    {"ko", "kor", "korean"},
    {"zh", "zho", "chi", "chinese"},
}

local function norm(lang)
    if not lang then return nil end
    return lang:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function expand(lang)
    -- returns the set of equivalent codes for a language
    local n = norm(lang)
    if not n or n == "" or n == "und" or n == "unknown" then return nil end
    for _, group in ipairs(alias_groups) do
        for _, member in ipairs(group) do
            if member == n then
                local set = {}
                for _, m in ipairs(group) do set[m] = true end
                return set
            end
        end
    end
    return {[n] = true}
end

local function build_allowed(tracks)
    local allowed = {}
    for code in opts.languages:gmatch("[^,]+") do
        local set = expand(code)
        if set then
            for m in pairs(set) do allowed[m] = true end
        end
    end
    -- source language = first audio track's language
    local source_lang
    for _, t in ipairs(tracks) do
        if t.type == "audio" then
            source_lang = t.lang
            break
        end
    end
    local src = expand(source_lang)
    if src then
        for m in pairs(src) do allowed[m] = true end
    end
    return allowed, source_lang
end

local function track_allowed(t, allowed)
    if t.external then return true end -- ar_subs fetches, manual loads
    local n = norm(t.lang)
    return n ~= nil and allowed[n] == true
end

local function sub_tracks(tracks, allowed)
    local subs = {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" and track_allowed(t, allowed) then
            table.insert(subs, t)
        end
    end
    return subs
end

local function label(t)
    local lang = t.lang or "und"
    if t.title and t.title ~= "" then
        return string.format("%s (%s)", lang, t.title)
    end
    return lang
end

local function announce(t, index, count)
    if t then
        mp.commandv("show-text", string.format("Subtitles [%d/%d]: %s", index, count, label(t)), 2000)
    else
        mp.commandv("show-text", "Subtitles: off", 2000)
    end
end

-- selection priority when the current track is outside the allow-list:
-- ar > en > source language > first allowed
local function pick_default(subs, allowed)
    local priority = {"ar", "ara", "arabic", "en", "eng", "english"}
    for _, code in ipairs(priority) do
        if allowed[code] then
            for _, t in ipairs(subs) do
                if norm(t.lang) == code then return t end
            end
        end
    end
    return subs[1]
end

local function on_track_list(_, tracks)
    if not tracks then return end
    local allowed, source = build_allowed(tracks)
    local subs = sub_tracks(tracks, allowed)

    local total, hidden = 0, 0
    local current
    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            total = total + 1
            if track_allowed(t, allowed) == false then hidden = hidden + 1 end
            if t.selected then current = t end
        end
    end

    mp.msg.info(string.format(
        "allow-list active: %d/%d sub tracks visible (source language: %s)",
        #subs, total, source or "untagged"
    ))

    -- publish for other UI (uosc track menu reads this to hide entries)
    local codes = {}
    for code in pairs(allowed) do codes[#codes + 1] = code end
    table.sort(codes)
    mp.set_property_native("user-data/sub_lang_filter/allowed", codes)
    mp.set_property_native("user-data/sub_lang_filter/source", source or "")
    mp.set_property_native("user-data/sub_lang_filter/active", total > 0)

    if not opts.enforce then return end
    if current and track_allowed(current, allowed) then return end
    local pick = pick_default(subs, allowed)
    if pick then
        mp.set_property_number("sid", pick.id)
    elseif current then
        -- nothing allowed at all: subs off rather than a hidden language
        mp.set_property("sid", "no")
    end
end

local function cycle(direction)
    local tracks = mp.get_property_native("track-list") or {}
    local allowed = build_allowed(tracks)
    local subs = sub_tracks(tracks, allowed)
    if #subs == 0 then
        mp.commandv("show-text", "Subtitles: no allow-listed tracks", 2000)
        return
    end
    local current_id = mp.get_property_native("sid")
    local index = nil
    for i, t in ipairs(subs) do
        if t.id == current_id then index = i; break end
    end
    local next
    if not index then
        next = direction > 0 and subs[1] or subs[#subs]
    elseif #subs == 1 then
        -- single allowed track: toggle it / off
        if current_id then
            mp.set_property("sid", "no")
            announce(nil)
            return
        end
        next = subs[1]
    else
        next = subs[((index - 1 + direction) % #subs) + 1]
    end
    mp.set_property_number("sid", next.id)
    for i, t in ipairs(subs) do
        if t.id == next.id then announce(next, i, #subs); break end
    end
end

mp.observe_property("track-list", "native", on_track_list)
mp.add_key_binding(nil, "cycle_sub_up", function() cycle(1) end)
mp.add_key_binding(nil, "cycle_sub_down", function() cycle(-1) end)
