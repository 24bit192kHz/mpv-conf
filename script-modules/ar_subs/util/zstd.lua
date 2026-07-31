-- zstd helpers for the ar_subs cache: subtitles live compressed at rest
-- (*.ass.zst / *.srt.zst) and are decompressed on demand into the hot dir.
--
-- Fast path: LuaJIT FFI straight into libzstd -- in-process, no subprocess
-- spawn (a ~300KB subtitle decompresses in well under a millisecond, versus
-- ~5-10ms to fork the zstd CLI). CLI fallback if the library is missing.

local ffi_ok, ffi = pcall(require, "ffi")

local M = {}

local z = nil
if ffi_ok then
    local loaded, lib = pcall(ffi.load, "libzstd.so.1")
    if not loaded then loaded, lib = pcall(ffi.load, "libzstd.so") end
    if loaded then
        pcall(ffi.cdef, [[
            unsigned long long ZSTD_getFrameContentSize(const void *src, size_t srcSize);
            size_t ZSTD_decompress(void *dst, size_t dstCapacity,
                                   const void *src, size_t srcSize);
            size_t ZSTD_compress(void *dst, size_t dstCapacity,
                                 const void *src, size_t srcSize, int level);
            size_t ZSTD_compressBound(size_t srcSize);
            unsigned ZSTD_isError(size_t code);
            const char *ZSTD_getErrorName(size_t code);
        ]])
        z = lib
    end
end

M.available = function() return z ~= nil end

local ZSTD_ERROR_MARK = 2 ^ 62 -- content-size error/unknown sentinels are huge unsigned

-- Compress a string (level 19 = near-max ratio, still >100MB/s on x86).
M.compress = function(data, level)
    if not z then return nil, "no libzstd" end
    level = level or 19
    local bound = tonumber(z.ZSTD_compressBound(#data))
    local dst = ffi.new("uint8_t[?]", bound)
    local n = z.ZSTD_compress(dst, bound, data, #data, level)
    if z.ZSTD_isError(n) ~= 0 then
        return nil, ffi.string(z.ZSTD_getErrorName(n))
    end
    return ffi.string(dst, tonumber(n))
end

-- Decompress a zstd frame whose content size is in the header (always true
-- for frames produced by compress() above).
M.decompress = function(data)
    if not z then return nil, "no libzstd" end
    local size = z.ZSTD_getFrameContentSize(data, #data)
    if size >= ZSTD_ERROR_MARK then return nil, "no frame content size" end
    size = tonumber(size)
    local dst = ffi.new("uint8_t[?]", size)
    local n = z.ZSTD_decompress(dst, size, data, #data)
    if z.ZSTD_isError(n) ~= 0 then
        return nil, ffi.string(z.ZSTD_getErrorName(n))
    end
    return ffi.string(dst, tonumber(n))
end

-- File-level convenience (subtitles are small; whole-file read is fine).
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a"); f:close()
    return data
end

local function write_file(path, data)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(data); f:close()
    return true
end

-- Decompress src (.zst) to dst (plain). Subprocess fallback when FFI is
-- unavailable. Returns true on success.
M.decompress_file = function(src, dst)
    local data = read_file(src)
    if not data then return false end
    local out, err = M.decompress(data)
    if out then return write_file(dst, out) end
    -- CLI fallback
    local mp = M._mp
    if mp then
        local ret = mp.command_native({ name = "subprocess", playback_only = false,
            capture_stdout = false, capture_stderr = false,
            args = { "zstd", "-d", "-q", "-f", "-o", dst, src } })
        return ret ~= nil and ret.status == 0
    end
    return false, err
end

-- Compress src to dst (.zst) and optionally remove src.
M.compress_file = function(src, dst, remove_src, level)
    local data = read_file(src)
    if not data then return false end
    local out = M.compress(data, level)
    if out and write_file(dst, out) then
        if remove_src then os.remove(src) end
        return true
    end
    local mp = M._mp
    if mp then
        local args = { "zstd", "-" .. tostring(level or 19), "-q", "-f", "-o", dst, src }
        local ret = mp.command_native({ name = "subprocess", playback_only = false,
            capture_stdout = false, capture_stderr = false, args = args })
        if ret ~= nil and ret.status == 0 then
            if remove_src then os.remove(src) end
            return true
        end
    end
    return false
end

M.is_compressed = function(path) return path:sub(-4) == ".zst" end
M.strip_zst = function(path)
    return M.is_compressed(path) and path:sub(1, -5) or path
end

------------------------------------------------------------
-- Hot dir: subs live compressed at rest (*.ass.zst in the cache tree); mpv
-- needs a real file path, so on load the sub is decompressed here once and
-- served from then on. Decompression is in-process FFI (sub-millisecond for
-- a ~300KB subtitle), so loading a compressed sub is indistinguishable from
-- loading a raw one. Retimed files are never evicted (the autosubsync
-- transform cache references their paths; evicting one would force a full
-- re-sync on the next replay).

local HOT_CAP = 128
local hot_dir_cached

M.hot_dir = function()
    if not hot_dir_cached then
        hot_dir_cached = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") or "/tmp") .. "/.cache") .. "/mpv/ar_subs/hot"
        os.execute("mkdir -p " .. hot_dir_cached)
    end
    return hot_dir_cached
end

local function hot_lru()
    local h = io.popen("ls -1t " .. M.hot_dir() .. " 2>/dev/null")
    if not h then return end
    local kept, victims = 0, {}
    for name in h:lines() do
        if name:find("_retimed", 1, true) then
            -- never evict retimed files (transform cache references them)
        else
            kept = kept + 1
            if kept > HOT_CAP then victims[#victims + 1] = name end
        end
    end
    h:close()
    for _, name in ipairs(victims) do
        os.remove(M.hot_dir() .. "/" .. name)
    end
end

-- Path mpv should load: decompresses .zst into the hot dir on first use,
-- returns plain paths unchanged. Touches the hot file so LRU keeps it.
M.ensure = function(path)
    if type(path) ~= "string" or not M.is_compressed(path) then return path end
    local base = path:match("([^/]+)$"):sub(1, -5)
    local out = M.hot_dir() .. "/" .. base
    local f = io.open(out, "rb")
    if f then
        f:close()
        local t = io.open(out, "ab"); if t then t:close() end -- LRU touch
        return out
    end
    if M.decompress_file(path, out) then
        hot_lru()
        return out
    end
    return path -- let the caller's own missing-file handling report it
end

-- Compress a freshly saved subtitle in place (name.ass -> name.ass.zst).
-- Returns the path to use from now on (the .zst on success, the original
-- when compression is unavailable/failed).
M.archive_in_place = function(path)
    if M.is_compressed(path) then return path end
    if path:find("_retimed", 1, true) then return path end -- hot artifact
    local zpath = path .. ".zst"
    if M.compress_file(path, zpath, true, 19) then return zpath end
    return path
end

-- mp is injected by the caller (ar_subs passes its mp handle) for the CLI
-- fallback; pure FFI operation needs nothing.
M.init = function(mp) M._mp = mp end

return M
