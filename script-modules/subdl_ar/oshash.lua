-- subdl_ar.oshash: OpenSubtitles hash (OSHash) computation.
--
-- Pure-Lua implementation of the OpenSubtitles file hash algorithm.
-- Used for hash-based subtitle matching via the OpenSubtitles REST API.
--
-- Algorithm:
--   1. Read 64 chunks of 8 bytes from the first 64KB (head).
--   2. Read 64 chunks of 8 bytes from the last 64KB (tail).
--   3. XOR-fold each set of 64 uint64 values into a single uint64.
--   4. Hash = head_hash XOR tail_hash XOR file_size.
--
-- Files smaller than 128KB cannot produce a valid hash (head and tail
-- would overlap entirely). Returns nil for such files.

local M = {}

local CHUNK_SIZE = 8
local NUM_CHUNKS = 64
local HALF_SIZE = NUM_CHUNKS * CHUNK_SIZE  -- 512 bytes
local MIN_FILE_SIZE = HALF_SIZE * 2        -- 1024 bytes minimum for non-overlapping head+tail

-- Read exactly `n` bytes from file handle `f` at absolute position `pos`.
-- Returns the bytes string, or nil on short/failed read.
local function read_at(f, pos, n)
  f:seek("set", pos)
  return f:read(n)
end

-- XOR-fold a byte string into a single uint64.
-- Processes 8 bytes at a time. For each chunk, interpret as a big-endian
-- unsigned 64-bit integer and XOR it into the accumulator.
local function xor_fold(bytes)
  local acc = 0
  for i = 1, #bytes - CHUNK_SIZE + 1, CHUNK_SIZE do
    local a = string.byte(bytes, i)
    local b = string.byte(bytes, i + 1)
    local c = string.byte(bytes, i + 2)
    local d = string.byte(bytes, i + 3)
    local e = string.byte(bytes, i + 4)
    local f = string.byte(bytes, i + 5)
    local g = string.byte(bytes, i + 6)
    local h = string.byte(bytes, i + 7)
    local chunk = a * 0x100000000000000
                 + b * 0x1000000000000
                 + c * 0x10000000000
                 + d * 0x100000000
                 + e * 0x1000000
                 + f * 0x10000
                 + g * 0x100
                 + h
    acc = acc ~ chunk
  end
  return acc
end

-- Compute OSHash from a raw byte string.
-- Returns 16-char lowercase hex string, or nil if data is too short.
function M.compute_string(data)
  if type(data) ~= "string" or #data < MIN_FILE_SIZE then
    return nil
  end

  local file_size = #data

  -- Head: first 512 bytes
  local head = data:sub(1, HALF_SIZE)
  -- Tail: last 512 bytes
  local tail = data:sub(file_size - HALF_SIZE + 1)

  local h = xor_fold(head) ~ xor_fold(tail) ~ file_size

  return string.format("%016x", h & 0xFFFFFFFFFFFFFFFF)
end

-- Compute OSHash from a file path.
-- Returns 16-char lowercase hex string, or nil on error / too small.
function M.compute_file(path)
  if not path or path == "" then return nil end

  local f = io.open(path, "rb")
  if not f then return nil end

  local file_size = f:seek("end")
  if not file_size or file_size < MIN_FILE_SIZE then
    f:close()
    return nil
  end

  -- Head: first 512 bytes
  local head = read_at(f, 0, HALF_SIZE)
  if not head or #head < HALF_SIZE then
    f:close()
    return nil
  end

  -- Tail: last 512 bytes
  local tail_pos = file_size - HALF_SIZE
  local tail = read_at(f, tail_pos, HALF_SIZE)
  if not tail or #tail < HALF_SIZE then
    f:close()
    return nil
  end

  f:close()

  local h = xor_fold(head) ~ xor_fold(tail) ~ file_size

  return string.format("%016x", h & 0xFFFFFFFFFFFFFFFF)
end

return M
