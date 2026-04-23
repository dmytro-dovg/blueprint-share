
local Log = require "scripts.log"
local Util = require "scripts.util"

local this = {}

local consts = {
  gui = {
    slot_prefix = "slot_",
    frame = "blueprint-share_inbox",
    button = "button",
    flow = {
      item_info = "item_info",
    },
    label = {
      title = "title",
      description = "description",
    },
    tag = {
      slot = "blueprint-share_inbox_slot",
    },
  }
}

function consts.gui.slot(index)
  return consts.gui.slot_prefix .. index
end

local function get_frame(player)
  return player.gui.screen[consts.gui.frame]
end

local function build(player)
  if get_frame(player) then
    get_frame(player).destroy()
  end
  local frame = player.gui.screen.add{
    type = "frame",
    name = consts.gui.frame,
    direction = "vertical",
    caption = {"blueprint-share.gui-inbox-title"},
  }

  local player_storage = storage.players[player.index]
  if not player_storage then return end

  local inventory = player_storage.inbox_inventory
  if not inventory or not inventory.valid then return end

  for slot = 1, #inventory do
    if slot > 1 then
      frame.add {
        type = "line",
      }
    end
    local flow = frame.add {
      type = "flow",
      name = consts.gui.slot(slot),
    }
    flow.style.vertical_align = "center"

    local button = flow.add {
      type = "sprite-button",
      name = consts.gui.button,
      style = "slot_button",
      enabled = false,
      tags = { [consts.gui.tag.slot] = slot }
    }

    local labels_flow = flow.add {
      type = "flow",
      direction = "vertical",
      name = consts.gui.flow.item_info,
    }
    labels_flow.style.vertically_stretchable = true
    labels_flow.style.vertical_align = "center"

    local title_label = labels_flow.add { 
      type = "label",
      name = consts.gui.label.title,
      caption = {"blueprint-share.gui-empty"},
    }
    title_label.style.width = 150
    title_label.style.single_line = true

    local description_label = labels_flow.add { 
      type = "label",
      name = consts.gui.label.description,
    }
    description_label.style.width = 150
    description_label.style.single_line = true
  end
  
  return frame
end

function this.update(player)
  local frame = get_frame(player) or build(player)

  local player_storage = storage.players[player.index]
  if not player_storage then return end

  local inventory = player_storage.inbox_inventory
  if not inventory or not inventory.valid then return end

  for slot = 1, #inventory do
    local item = inventory[slot]
    local container = frame[consts.gui.slot(slot)]
    local button = container[consts.gui.button]
    local item_info_flow = container[consts.gui.flow.item_info]
    local title_label = item_info_flow[consts.gui.label.title]
    local description_label = item_info_flow[consts.gui.label.description]

    if item and item.valid_for_read then
      button.enabled = true
      button.sprite = "item/" .. item.name
      title_label.caption = (item.label ~= "" and item.label) or item.prototype.localised_name

      if item.is_blueprint or item.is_blueprint_book then
        local desc = item.blueprint_description or ""
        description_label.caption = desc
        description_label.visible = #desc > 0
      else
        description_label.caption = ""
        description_label.visible = false
      end
    else
      button.enabled = false
      button.sprite = nil
      title_label.caption = {"blueprint-share.gui-empty"}
      description_label.caption = ""
      description_label.visible = false
    end
  end
end

function this.process_payload(payload, player)
  if not (player and player.valid) then return end

  local player_storage = storage.players[player.index]
  if not player_storage then return end
  
  local inventory = player_storage.inbox_inventory
  if not inventory or not inventory.valid then return end

  local size = #inventory
  if size == 0 then return end

  -- Validate import in a temp inventory
  local temp = game.create_inventory(1)
  local result = temp[1].import_stack(payload)
  if result == 1 then
    Log.debug("Inbox: Import failed", player)
    temp.destroy()
    return
  end

  -- Import successfuly
  for slot = 1, size - 1 do
    inventory[slot].set_stack(inventory[slot + 1])
  end

  inventory[size].clear()
  inventory[size].set_stack(temp[1])
  temp.destroy()
end

function this.on_click(event)
  local player = Util.valid_player(event)
  if not player then return end
  
  local slot = event.element.tags[consts.gui.tag.slot]
  if not slot then return end

  local player_storage = storage.players[player.index]
  if not player_storage then return end

  local inventory = player_storage.inbox_inventory
  if not inventory or not inventory.valid then return end

  if event.button == defines.mouse_button_type.left then
    if not player.is_cursor_empty() then return end
    player.cursor_stack.set_stack(inventory[slot])
    player.cursor_stack_temporary = true
  elseif event.button == defines.mouse_button_type.right then
    inventory[slot].clear()
  end
  this.update(player)
end

return this
