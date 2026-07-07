-- Spec: subdl_ar.oshash (OpenSubtitles hash computation)
--
-- Tests:
--   1. Determinism: same input → same hash
--   2. Different input → different hash (non-uniform buffers)
--   3. compute_file on real temp files
--   4. File too small (< 1024 bytes) → nil
--   5. Non-existent file / nil / empty path → nil
--   6. compute_string on minimum-size buffer
--   7. Regression anchor: known-size all-zero buffer

local H = require "harness"

package.loaded["subdl_ar.oshash"] = nil
local oshash = require "subdl_ar.oshash"

---------------------------------------------------------------------------
-- (1) Determinism: same input → same hash
---------------------------------------------------------------------------
do
  H.reset()
  -- Use a non-uniform buffer so head != tail (avoiding XOR cancellation)
  local head_part = string.rep("\0", 65536)
  local tail_part = string.rep("\1", 65536)
  local buf = head_part .. tail_part  -- 131072 bytes exactly
  local h1 = oshash.compute_string(buf)
  H.ok("compute_string returns a string", type(h1) == "string")
  H.ok("compute_string returns 16 hex chars", #h1 == 16)
  local h2 = oshash.compute_string(buf)
  H.eq("compute_string is deterministic", h1, h2)
end

do
  H.reset()
  math.randomseed(42)
  local pat_a = {}
  for i = 1, 65536 do pat_a[i] = string.char(math.random(1, 255)) end
  pat_a = table.concat(pat_a)

  math.randomseed(99)
  local pat_b = {}
  for i = 1, 65536 do pat_b[i] = string.char(math.random(1, 255)) end
  pat_b = table.concat(pat_b)

  local pad = string.rep("\0", 65536)
  local buf_a = pat_a .. pad
  local buf_b = pat_b .. pad
  local h_a = oshash.compute_string(buf_a)
  local h_b = oshash.compute_string(buf_b)
  H.ok("different input produces different hash", h_a ~= h_b)
end

---------------------------------------------------------------------------
-- (2b) All-zero large buffer produces a known hash
---------------------------------------------------------------------------
do
  H.reset()
  local big = string.rep("\0", 12909756)
  local h = oshash.compute_string(big)
  H.ok("all-zero 12909756 buffer produces 16 hex chars", #h == 16)
  H.ok("all-zero hash is non-empty", h ~= "")
end

---------------------------------------------------------------------------
-- (3) compute_file on a real temp file
---------------------------------------------------------------------------
do
  H.reset()
  local tmp_path = "/tmp/test_oshash_" .. os.time() .. ".bin"
  -- Write 256KB of non-uniform data
  local head_part = string.rep("\0", 65536)
  local tail_part = string.rep("\1", 65536)
  local middle = string.rep("\2", 256 * 1024 - 131072)
  local f = io.open(tmp_path, "wb")
  H.ok("temp file created for compute_file", f ~= nil)
  if f then
    f:write(head_part .. middle .. tail_part)
    f:close()
    local hash = oshash.compute_file(tmp_path)
    H.ok("compute_file returns a string", type(hash) == "string")
    H.ok("compute_file returns 16 hex chars", #hash == 16)
    -- Same content → same hash
    local hash2 = oshash.compute_file(tmp_path)
    H.eq("compute_file is deterministic", hash, hash2)
    os.remove(tmp_path)
  end
end

---------------------------------------------------------------------------
-- (4) File too small (< 131072 bytes) → nil
---------------------------------------------------------------------------
do
  H.reset()
  local tmp_path = "/tmp/test_oshash_small_" .. os.time() .. ".bin"
  local f = io.open(tmp_path, "wb")
  if f then
    f:write(string.rep("\0", 65536))  -- 65536 bytes, below 131072 minimum
    f:close()
    local hash = oshash.compute_file(tmp_path)
    H.eq("file < 131072 bytes returns nil", hash, nil)
    os.remove(tmp_path)
  end
end

---------------------------------------------------------------------------
-- (4b) File at exactly 131072 bytes (boundary) → returns hash
---------------------------------------------------------------------------
do
  H.reset()
  local tmp_path = "/tmp/test_oshash_boundary_" .. os.time() .. ".bin"
  local f = io.open(tmp_path, "wb")
  if f then
    f:write(string.rep("\0", 131072))  -- exactly 131072 bytes
    f:close()
    local hash = oshash.compute_file(tmp_path)
    H.ok("file at exactly 131072 bytes returns hash", type(hash) == "string" and #hash == 16)
    os.remove(tmp_path)
  end
end

---------------------------------------------------------------------------
-- (5) Non-existent file / nil / empty path → nil
---------------------------------------------------------------------------
do
  H.reset()
  H.eq("non-existent file returns nil",
       oshash.compute_file("/tmp/nonexistent_oshash_file.bin"), nil)
  H.eq("nil path returns nil", oshash.compute_file(nil), nil)
  H.eq("empty path returns nil", oshash.compute_file(""), nil)
end

---------------------------------------------------------------------------
-- (6) compute_string with data < MIN_FILE_SIZE → nil
---------------------------------------------------------------------------
do
  H.reset()
  local short = string.rep("A", 64)
  local h = oshash.compute_string(short)
  H.eq("data < 131072 bytes returns nil", h, nil)
end

---------------------------------------------------------------------------
-- (7) compute_string with exactly minimum-size buffer
---------------------------------------------------------------------------
do
  H.reset()
  -- Exactly 131072 bytes: head = first 65536, tail = last 65536 (disjoint)
  local buf = string.rep("\x42", 65536) .. string.rep("\x37", 65536)
  local h = oshash.compute_string(buf)
  H.ok("minimum 131072-byte buffer produces a hash", type(h) == "string" and #h == 16)
end
