local Log = require "scripts.log"

local Util = {}

-- Also used for mapping stack types to prototype names for l10n
local valid_stack_types = {
  ["blueprint"] = "blueprint",
  ["blueprint-book"] = "blueprint-book",
  ["deconstruction-item"] = "deconstruction-planner",
  ["upgrade-item"] = "upgrade-planner",
}

local valid_record_types = {
  ["blueprint"] = true,
  ["blueprint-book"] = true,
  ["deconstruction-planner"] = true,
  ["upgrade-planner"] = true,
}

local function localised_item(item_name)
  return "__ITEM__" ..  item_name .. "__"
end

function Util.valid_player(event)
  local player_index = event.player_index

  -- Disable for servers
  if player_index == 0 then
    Log.debug("server receiving data is unsupported")
    return
  end

  local player = game.get_player(player_index)
  if not player then
    Log.debug("no player")
    return
  end
  return player
end

function Util.export_cursor_data(player)
  if not player then
    return
  end

  -- Determine what the player is holding
  local record = player.cursor_record
  local stack = player.cursor_stack

  -- Record from blueprint library
  if record and record.valid and valid_record_types[record.type] then
    local record_name = localised_item(record.type)
    if not record.is_preview then
      return record.export_record(), record_name
    else
      Log.warn({"blueprint-share.warning-record-in-preview"}, player)
      return
    end
  end

  -- Stack from cursor
  if stack and stack.valid and stack.valid_for_read and valid_stack_types[stack.type] then
    return stack.export_stack(), localised_item(valid_stack_types[stack.type])
  end
end

return Util
