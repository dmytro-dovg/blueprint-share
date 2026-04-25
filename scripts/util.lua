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
  if player and player.valid then
    return player
  end
  Log.debug("no player")
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

function Util.signal_sprite_path(signal)
  local signal_type = signal.type == "virtual" and "virtual-signal" or (signal.type or "item")
  return signal_type .. "/" .. signal.name
end

function Util.active_book_stack(stack)
  local current_stack = stack
  while current_stack and current_stack.valid_for_read and current_stack.is_blueprint_book do
    -- If the book has its own custom icons, use them
    local book_icons = current_stack.preview_icons
    if book_icons and #book_icons > 0 then
      return current_stack
    end

    local inventory = current_stack.get_inventory(defines.inventory.item_main)
    if not (inventory and current_stack.active_index) then return current_stack end
    local next_stack = inventory[current_stack.active_index]
    if not (next_stack and next_stack.valid_for_read) then
      return current_stack
    end
    current_stack = next_stack
  end
  return current_stack
end

function Util.tooltip(title, description, icons)
  local sections = {}

  if title then
    table.insert(sections, {"", "[font=default-bold]", title, "[/font]"})
  end

  local icons_section = {""}
  local count = 0
  for _, icon in ipairs(icons or {}) do
    local signal = icon.signal
    if signal and signal.name then
      count = count + 1
      table.insert(icons_section, "[img=" .. Util.signal_sprite_path(signal) .. "]" .. (count == 2 and "\n" or " "))
    end
  end
  if count > 0 then table.insert(sections, icons_section) end

  if description and #description > 0 then
    table.insert(sections, description)
  end

  local tooltip = {""}
  for i, section in ipairs(sections) do
    if i > 1 then
      table.insert(tooltip, "\n[color=gray]────────────────[/color]\n")
    end
    table.insert(tooltip, section)
  end
  return tooltip
end

function Util.deconstruction_item_icons(stack)
  local icons = {}
  local function add_icon(icon_type, name)
    if not name then return end
    icons[#icons + 1] = {
      signal = {
        name = name,
        type = icon_type,
      },
    }
    return #icons >= 4
  end

  if stack.trees_and_rocks_only then
    icons[#icons + 1] = { sprite = "utility/nature_icon" }
  else
    local mode = stack.tile_selection_mode
    local show_entities = mode ~= defines.deconstruction_item.tile_selection_mode.only
    local show_tiles = mode ~= defines.deconstruction_item.tile_selection_mode.never

    if show_entities then
      for i = 1, stack.entity_filter_count do
        local filter = stack.get_entity_filter(i)
        if filter and add_icon("entity", filter.name) then break end
      end
    end

    if show_tiles and #icons < 4 then
      for i = 1, stack.tile_filter_count do
        local name = stack.get_tile_filter(i)
        if name and add_icon("tile", name) then break end
      end
    end
  end
  return icons
end

function Util.upgrade_item_icons(stack)
  local seen, icons = {}, {}
  for i = 1, stack.mapper_count do
    local to = stack.get_mapper(i, "to")
    local from = stack.get_mapper(i, "from")
    if from and from.name and to and to.name then
      local icon = to.type .. "/" .. to.name
      if not seen[icon] then
        seen[icon] = true
        icons[#icons + 1] = {
          signal = {
            name = to.name,
            type = to.type,
          },
        }
        if #icons == 4 then break end
      end
    end
  end
  return icons
end

return Util
