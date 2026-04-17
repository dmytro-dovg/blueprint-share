local Settings = require "scripts.settings"
local Log = {}

local levels = {
  quiet = 0,
  error = 1,
  warn = 2,
  info = 3,
  debug = 4,
}

local function log_to_file(level, msg)
  if type(msg) == "string" then
    log("blueprint-share: " .. level .. ": " .. msg)
  elseif type(msg) == "table" then
    log("blueprint-share: " .. level .. ": " .. helpers.table_to_json(msg))
  end
end

local function should_print(level, player)
  if not player then return false end
  local setting = Settings.log_level(player)
  return levels[level] <= levels[setting]
end

function Log.debug(msg, player)
  log_to_file("debug", msg)
  if should_print("debug", player) then
    player.print(msg, { sound = defines.print_sound.never })
  end
end

function Log.info(msg, player)
  log_to_file("info", msg)
  if should_print("info", player) then
    player.print(msg, { sound = defines.print_sound.never })
  end
end

function Log.warn(msg, player)
  log_to_file("warn", msg)
  if should_print("warn", player) then
    player.print({"", "[color=yellow]", msg, "[/color]"})
  end
end

function Log.error(msg, player)
  log_to_file("error", msg)
  if should_print("error", player) then
    player.print({"", "[color=red]", msg, "[/color]"})
  end
end

return Log