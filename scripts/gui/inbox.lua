
local Log = require "scripts.log"
local Util = require "scripts.util"

local this = {}

local consts = {
  gui = {
    inbox = {
      frame = "blueprint-share-gui-inbox-frame",
      button = {
        slot = "blueprint-share-gui-inbox-button-slot",
        close = "blueprint-share-gui-inbox-button-close",
      },
      flow = {
        slot_prefix = "blueprint-share-gui-inbox-flow-slot_",
        titlebar = "blueprint-share-gui-inbox-flow-titlebar",
        content = "blueprint-share-gui-inbox-flow-content",
        item_info = "blueprint-share-gui-inbox-flow-item_info",
      },
      label = {
        title = "blueprint-share-gui-inbox-label-title",
        description = "blueprint-share-gui-inbox-label-description",
      },
      tag = {
        slot = "blueprint-share-gui-inbox-tag-slot",
      },
    },
  },
}

function consts.gui.inbox.flow.slot(index)
  return consts.gui.inbox.flow.slot_prefix .. index
end

local function get_frame(player)
  return player.gui.screen[consts.gui.inbox.frame]
end

local function build_tooltip(stack, title, description)
  local tooltip = {""}

  if title then
    table.insert(tooltip, {"", "[font=default-bold]", title, "[/font]"})
  end
  table.insert(tooltip, "\n[color=gray]────────────────[/color]\n")

  local count = 0
  local icons = stack.preview_icons
  for _, icon in ipairs(icons) do
    local signal = icon.signal
    if signal and signal.name then
      local signal_type = signal.type == "virtual" and "virtual-signal" or (signal.type or "item")
      count = count + 1
      table.insert(tooltip, "[img=" .. signal_type .. "." .. signal.name .. "]" .. (count == 2 and "\n" or " "))
    end
  end

  if description and #description > 0 then
    table.insert(tooltip, "\n[color=gray]────────────────[/color]\n")
    table.insert(tooltip, description)
  end
  return tooltip
end

local function build(player)
  if get_frame(player) then
    get_frame(player).destroy()
  end
  local frame = player.gui.screen.add{
    type = "frame",
    name = consts.gui.inbox.frame,
    direction = "vertical",
  }

  -- Titlebar
  local titlebar = frame.add {
    type = "flow",
    name = consts.gui.inbox.flow.titlebar,
  }
  titlebar.drag_target = frame

  titlebar.add {
    type = "label",
    style = "frame_title",
    caption = {"blueprint-share.gui-inbox-title"},
    ignored_by_interaction = true,
  }

  local filler = titlebar.add {
    type = "empty-widget",
    style = "draggable_space_header",
    ignored_by_interaction = true,
  }
  filler.style.horizontally_stretchable = true
  filler.style.height = 24
  filler.style.right_margin = 4

  -- Close button
  titlebar.add {
    type = "sprite-button",
    name = consts.gui.inbox.button.close,
    style = "frame_action_button",
    sprite = "utility/close",
    clicked_sprite = "utility/close_black",
  }

  local content = frame.add {
    type = "flow",
    direction = "vertical",
    name = consts.gui.inbox.flow.content,
  }

  local player_storage = storage.players[player.index]
  if not player_storage then return end

  local inventory = player_storage.inbox_inventory
  if not inventory or not inventory.valid then return end

  for slot = 1, #inventory do
    if slot > 1 then
      content.add {
        type = "line",
      }
    end
    
    local slot_content = content.add {
      type = "flow",
      name = consts.gui.inbox.flow.slot(slot),
    }
    slot_content.style.vertical_align = "center"

    local button = slot_content.add {
      type = "sprite-button",
      name = consts.gui.inbox.button.slot,
      style = "slot_button",
      enabled = false,
      tags = { [consts.gui.inbox.tag.slot] = slot },
    }

    local labels_flow = slot_content.add {
      type = "flow",
      direction = "vertical",
      name = consts.gui.inbox.flow.item_info,
    }
    labels_flow.style.vertically_stretchable = true
    labels_flow.style.vertical_align = "center"

    local title_label = labels_flow.add { 
      type = "label",
      name = consts.gui.inbox.label.title,
      caption = {"blueprint-share.gui-empty"},
    }
    title_label.style.width = 150
    title_label.style.single_line = true

    local description_label = labels_flow.add { 
      type = "label",
      name = consts.gui.inbox.label.description,
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
    local content = frame[consts.gui.inbox.flow.content][consts.gui.inbox.flow.slot(slot)]
    local button = content[consts.gui.inbox.button.slot]
    local item_info_flow = content[consts.gui.inbox.flow.item_info]
    local title_label = item_info_flow[consts.gui.inbox.label.title]
    local description_label = item_info_flow[consts.gui.inbox.label.description]

    if item and item.valid_for_read then
      button.enabled = true
      button.sprite = "item/" .. item.name
      local title = (item.label ~= "" and item.label) or item.prototype.localised_name
      title_label.caption = title

      local desc
      if item.is_blueprint or item.is_blueprint_book then
        desc = item.blueprint_description or ""
        description_label.caption = desc
        description_label.visible = #desc > 0
      else
        description_label.caption = ""
        description_label.visible = false
      end
      button.tooltip = build_tooltip(item, title, desc)
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

  if event.element.name == consts.gui.inbox.button.close then
    local frame = get_frame(player)
    if frame then frame.destroy() end
    return
  end

  local slot = event.element.tags[consts.gui.inbox.tag.slot]
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
