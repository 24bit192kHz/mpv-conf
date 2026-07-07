-- subdl_ar.oshash: OpenSubtitles hash (OSHash) computation.
--
-- Pure-Lua implementation of the OpenSubtitles file hash algorithm.
-- Used for hash-based subtitle matching via the OpenSubtitles REST API.
--
-- Algorithm:
--   1. Read 64KB (65536 bytes) from the start of the file.
--   2. Read 64KB (65536 bytes) from the end of the file.
--   3. Sum all 64-bit unsigned integers (little-endian), plus the file size.
--
-- Files smaller than 128KB cannot produce a valid hash (head and tail
-- would overlap entirely). Returns nil for such files.

local M = {}

local CHUNK_SIZE = 65536
local MIN_FILE_SIZE = CHUNK_SIZE * 2

local function add64(lo1, hi1, lo2, hi2)
    local lo = lo1 + lo2
    local hi = hi1 + hi2
    if lo >= 4294967296 then
        lo = lo - 4294967296
        hi = hi + 1
    end
    if hi >= 4294967296 then
        hi = hi - 4294967296
    end
    return lo, hi
end

local function compute_hash_core(data, file_size)
    local lo_acc = file_size % 4294967296
    local hi_acc = math.floor(file_size / 4294967296)

    for i = 1, #data - 7, 8 do
        local b1, b2, b3, b4, b5, b6, b7, b8 = string.byte(data, i, i + 7)
        local lo = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
        local hi = b5 + b6 * 256 + b7 * 65536 + b8 * 16777216
        lo_acc, hi_acc = add64(lo_acc, hi_acc, lo, hi)
    end
    return string.format("%08x%08x", hi_acc, lo_acc)
end

function M.compute_string(data)
    if type(data) ~= "string" then return nil end
    local file_size = #data
    if file_size < MIN_FILE_SIZE then
        return nil
    end

    local head = data:sub(1, CHUNK_SIZE)
    local tail = data:sub(file_size - CHUNK_SIZE + 1)

    return compute_hash_core(head .. tail, file_size)
end

function M.compute_file(path)
    if not path or path == "" then return nil end

    local f = io.open(path, "rb")
    if not f then return nil end

    local file_size = f:seek("end")
    if not file_size or file_size < MIN_FILE_SIZE then
        f:close()
        return nil
    end

    f:seek("set", 0)
    local head = f:read(CHUNK_SIZE)
    f:seek("set", file_size - CHUNK_SIZE)
    local tail = f:read(CHUNK_SIZE)
    f:close()

    if not head or #head < CHUNK_SIZE or not tail or #tail < CHUNK_SIZE then
        return nil
    end

    return compute_hash_core(head .. tail, file_size)
end

return M
