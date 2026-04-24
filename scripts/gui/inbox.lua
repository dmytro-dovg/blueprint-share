
local Log = require "scripts.log"
local Util = require "scripts.util"
local InboxSlot = require "scripts.gui.inbox_slot"

local this = {}

local consts = {
  gui = {
    inbox = {
      frame = {
        main = "blueprint-share-gui-inbox-frame-main",
        content = "blueprint-share-gui-inbox-frame-content",
      },
      button = {
        slot = "blueprint-share-gui-inbox-button-slot",
        close = "blueprint-share-gui-inbox-button-close",
      },
      flow = {
        slot_prefix = "blueprint-share-gui-inbox-flow-slot_",
        titlebar = "blueprint-share-gui-inbox-flow-titlebar",
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
  return player.gui.screen[consts.gui.inbox.frame.main]
end

local function build_tooltip(stack, title, description)
  local sections = {}

  if title then
    table.insert(sections, {"", "[font=default-bold]", title, "[/font]"})
  end

  local icons_section = {""}
  local count = 0
  for _, icon in ipairs(stack.preview_icons or {}) do
    local signal = icon.signal
    if signal and signal.name then
      local signal_type = signal.type == "virtual" and "virtual-signal" or (signal.type or "item")
      count = count + 1
      table.insert(icons_section, "[img=" .. signal_type .. "." .. signal.name .. "]" .. (count == 2 and "\n" or " "))
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

local function build_frame(player)
  if get_frame(player) then return end
  local frame = player.gui.screen.add{
    type = "frame",
    name = consts.gui.inbox.frame.main,
    direction = "vertical",
  }

  local player_storage = storage.players[player.index]
  if player_storage then
    frame.location = player_storage.inbox_location or { 24, player.display_resolution.height / 2 - 190 }
  end

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
    type = "frame",
    style = "inside_shallow_frame",
    direction = "vertical",
    name = consts.gui.inbox.frame.content,
  }

  -- Player storage is mandatory for next steps
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
    slot_content.style.padding = 8
    slot_content.style.height = 54

    local slot_container = InboxSlot.build(slot_content, consts.gui.inbox.button.slot, nil)
    InboxSlot.set_tags(slot_container, { [consts.gui.inbox.tag.slot] = slot })

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
      style = "caption_label",
      caption = {"blueprint-share.gui-empty"},
    }
    title_label.style.width = 200
    title_label.style.single_line = true

    local description_label = labels_flow.add { 
      type = "label",
      name = consts.gui.inbox.label.description,
    }
    description_label.style.width = 200
    description_label.style.single_line = true
  end
  return frame
end

local function compact(inventory)
  local size = #inventory
  local write = size
  for read = size, 1, -1 do
    if inventory[read].valid_for_read then
      if read ~= write then
        inventory[write].swap_stack(inventory[read])
      end
      write = write - 1
    end
  end
end

function this.update(player)
  local frame = get_frame(player) or build_frame(player)

  local player_storage = storage.players[player.index]
  if not player_storage then return end

  local inventory = player_storage.inbox_inventory
  if not inventory or not inventory.valid then return end

  for slot = 1, #inventory do
    local item = inventory[slot]
    local content = frame[consts.gui.inbox.frame.content][consts.gui.inbox.flow.slot(slot)]
    local slot_container = content[consts.gui.inbox.button.slot]
    local item_info_flow = content[consts.gui.inbox.flow.item_info]
    local title_label = item_info_flow[consts.gui.inbox.label.title]
    local description_label = item_info_flow[consts.gui.inbox.label.description]

    if item and item.valid_for_read then
      InboxSlot.set_enabled(slot_container, true)
      InboxSlot.set_type(slot_container, item.name)
      InboxSlot.set_icons(slot_container, item.name, item.preview_icons)

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
      InboxSlot.set_tooltip(slot_container, build_tooltip(item, title, desc))
    else
      InboxSlot.set_enabled(slot_container, false)
      InboxSlot.set_type(slot_container)
      InboxSlot.set_icons(slot_container, nil, nil)
      InboxSlot.set_tooltip(slot_container, nil)
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

local function show(player, should_show)
  local frame = get_frame(player)
  if should_show and not frame then
    build_frame(player)
    this.update(player)
  elseif not should_show and frame then
    local player_storage = storage.players[player.index]
    if player_storage then
      player_storage.inbox_location = frame.location
    end
    frame.destroy()
  end
end

function this.toggle(event)
  local player = Util.valid_player(event)
  if not player then return end
  show(player, not get_frame(player))
end

function this.on_click(event)
  local player = Util.valid_player(event)
  if not player then return end

  if event.element.name == consts.gui.inbox.button.close then
    show(player, false)
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
    compact(inventory)
  end
  this.update(player)
end

return this
