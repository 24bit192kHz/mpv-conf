-- subdl_ar.config: load runtime configuration from .env + environment + script-opts.
--
-- This module extracts the read_dotenv + config-table pattern from the top of
-- the original monolith. The orchestrator calls load(mp, options) once at
-- startup; the actual API keys live in the returned tables, not in this module.

local url_util = require "subdl_ar.util.url"

local M = {}

local trim = url_util.trim
local strip_quotes = url_util.strip_quotes

function M.read_dotenv(mp)
  local dotenv = {}
  local path = mp.command_native({"expand-path", "~~/.env"})
  local file = io.open(path, "r")
  if not file then return dotenv end

  for line in file:lines() do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key and not key:match("^#") then
      dotenv[key] = strip_quotes(value)
    end
  end
  file:close()
  return dotenv
end

-- Returns: { dotenv=<table>, env=<table>, opts=<table filled by options.read_options> }
function M.load(mp, options)
  local dotenv = M.read_dotenv(mp)
  local env_config = {
    subdl_api_key = os.getenv("SUBDL_API_KEY") or dotenv.SUBDL_API_KEY or "",
    subdl_api_backup_key = os.getenv("SUBDL_API_KEY_BACKUP") or dotenv.SUBDL_API_KEY_BACKUP or "",
    tmdb_api_key = os.getenv("TMDB_API_KEY") or dotenv.TMDB_API_KEY or "",
    opensubs_api_key = os.getenv("OPENSUBS_API_KEY") or dotenv.OPENSUBS_API_KEY or "",
    opensubs_app_name = os.getenv("OPENSUBS_APP_NAME") or dotenv.OPENSUBS_APP_NAME or "",
  }
  local config = {
    subdl_api_key = "",
    subdl_api_backup_key = "",
    tmdb_api_key = "",
  }
  options.read_options(config, mp.get_script_name())

  -- Convenience: expose resolved values.
  return {
    dotenv = dotenv,
    env = env_config,
    opts = config,
    subdl_api_key = trim(config.subdl_api_key) ~= "" and config.subdl_api_key or env_config.subdl_api_key,
    subdl_api_backup_key = trim(config.subdl_api_backup_key) ~= "" and config.subdl_api_backup_key or env_config.subdl_api_backup_key,
    tmdb_api_key = trim(config.tmdb_api_key) ~= "" and config.tmdb_api_key or env_config.tmdb_api_key,
    opensubs_api_key = env_config.opensubs_api_key,
    opensubs_app_name = env_config.opensubs_app_name,
  }
end

return M
