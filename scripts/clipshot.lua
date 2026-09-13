---Screenshot the video and copy it to the clipboard
---@author ObserverOfTime
---@license 0BSD

---@class ClipshotOptions
---@field name string
---@field type string
local o = {
    name = 'mpv-screenshot.jpeg',
    type = '' -- defaults to jpeg
}
require('mp.options').read_options(o, 'clipshot')
local utils = require 'mp.utils'

local platform = mp.get_property_native('platform')
local seq = 0

local function base_dir()
    if platform == 'windows' then
        return os.getenv('TEMP') or os.getenv('TMP') or '.'
    elseif platform == 'darwin' then
        return os.getenv('TMPDIR') or '/tmp'
    end
    return os.getenv('XDG_RUNTIME_DIR') or '/tmp'
end

local function pid()
    local ok, v = pcall(function() return utils.getpid() end)
    if ok and v then return tostring(v) end
    return tostring(mp.get_property_number('pid', math.floor(mp.get_time() * 1000000)))
end

-- Unique file per capture: PID + monotonic sequence + timestamp so a
-- concurrent screenshot-to-file plus its async wl-copy/xclip can never
-- clobber or read each other's image (fixed /tmp/<name> raced).
local function unique_file()
    seq = seq + 1
    local stem, ext = (o.name or 'mpv-screenshot.jpeg'):match('^(.*)%.([^.]*)$')
    if not stem then stem, ext = (o.name or 'mpv-screenshot'), 'jpeg' end
    stem = stem:gsub('[^%w%._%-]+', '_')
    if stem == '' then stem = 'mpv-screenshot' end
    return string.format('%s/%s-%s-%d-%d.%s', base_dir(), stem, pid(), seq, os.time(), ext)
end

local function build_cmd(file)
    if platform == 'windows' then
        return {
            'powershell', '-NoProfile', '-Command',
            'Add-Type -Assembly System.Windows.Forms, System.Drawing;',
            string.format(
                "[Windows.Forms.Clipboard]::SetImage([Drawing.Image]::FromFile('%s'))",
                file:gsub("'", "''")
            )
        }
    elseif platform == 'darwin' then
        -- png: «class PNGf»
        local type = o.type ~= '' and o.type or 'JPEG picture'
        return {
            'osascript', '-e', string.format(
                'set the clipboard to (read (POSIX file %q) as %s)',
                file, type
            )
        }
    end
    if os.getenv('XDG_SESSION_TYPE') == 'wayland' then
        return {'sh', '-c', ('wl-copy < %q'):format(file)}
    else
        local type = o.type ~= '' and o.type or 'image/jpeg'
        return {'xclip', '-sel', 'c', '-t', type, '-i', file}
    end
end

---@param arg string
---@return fun()
local function clipshot(arg)
    return function()
        local file = unique_file()
        mp.commandv('screenshot-to-file', file, arg)
        mp.command_native_async({'run', unpack(build_cmd(file))}, function(suc, _, err)
            pcall(os.remove, file)
            mp.osd_message(suc and 'Copied screenshot to clipboard' or err, 1)
        end)
    end
end

mp.add_key_binding('c',     'clipshot-subs',   clipshot('subtitles'))
mp.add_key_binding('C',     'clipshot-video',  clipshot('video'))
mp.add_key_binding('Alt+c', 'clipshot-window', clipshot('window'))
