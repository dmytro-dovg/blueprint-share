local Util = require "scripts.util"

local this = {}

local consts = {
  gui = {
    inbox_slot = {
      flow = {
        overlay = "blueprint-share-gui-inbox-slot-flow-overlay",
      },
      button = {
        slot = "blueprint-share-gui-inbox-slot-button-slot",
      },
      table = {
        grid = "blueprint-share-gui-inbox-slot-table-grid"
      },
      sprites = {
        ["blueprint"] = "item/blueprint",
        ["blueprint-book"] = "item/blueprint-book",
        ["upgrade-planner"] = "item/upgrade-planner",
        ["deconstruction-planner"] = "item/deconstruction-planner",
      },
    },
  },
}

local function get_button(container)
  return container[consts.gui.inbox_slot.button.slot]
end

function this.set_icons(container, item_type, icons)
  local overlay = container[consts.gui.inbox_slot.flow.overlay]
  if not overlay then return end

  local grid = overlay[consts.gui.inbox_slot.table.grid]
  if not grid then return end

  grid.clear()

  icons = icons or {}
  local icon_size
  if item_type == "blueprint-book" then
    icon_size = #icons == 1 and { 14, 14 } or { 10, 10 }
  else
    icon_size = #icons == 1 and { 24, 24 } or { 14, 14 }
  end

  for _, icon in ipairs(icons) do
    local sprite_path
    if icon.sprite then
      sprite_path = icon.sprite
    elseif icon.signal and icon.signal.name then
      sprite_path = Util.signal_sprite_path(icon.signal)
    end

    if sprite_path then
      local icon_sprite = grid.add {
        type = "sprite",
        sprite = sprite_path,
      }
      icon_sprite.style.size = icon_size
      icon_sprite.style.stretch_image_to_widget_size = true
    end
  end
end

function this.build(parent, name, item_type)
  local sprite = consts.gui.inbox_slot.sprites[item_type]

  local container = parent.add {
    type = "flow",
    name = name,
    direction = "vertical",
  }
  container.style.width = 40
  container.style.height = 40

  local button = container.add {
    type = "sprite-button",
    name = consts.gui.inbox_slot.button.slot,
    sprite = sprite,
    style = "inventory_slot",
    enabled = false,
  }
  button.style.size = {40, 40}

  -- Centering flow overlaid on top of the button
  local overlay = container.add {
    type = "flow",
    name = consts.gui.inbox_slot.flow.overlay,
    direction = "vertical",
  }
  -- Extra 5 is needed to actually center the sprite
  overlay.style.top_margin = -45
  overlay.style.width = 40
  overlay.style.height = 40
  overlay.style.horizontal_align = "center"
  overlay.style.vertical_align = "center"
  overlay.ignored_by_interaction = true

  -- Table shrinks to content, flow centers it
  local grid = overlay.add {
    type = "table",
    name = consts.gui.inbox_slot.table.grid,
    column_count = 2,
  }
  grid.style.horizontal_spacing = 2
  grid.style.vertical_spacing = 2
  grid.style.horizontally_stretchable = false
  grid.style.vertically_stretchable = false
  return container
end

function this.set_type(container, item_type)
  local sprite = consts.gui.inbox_slot.sprites[item_type]
  get_button(container).sprite = sprite
end

function this.set_enabled(container, enabled)
  get_button(container).enabled = enabled
end

function this.set_tags(container, tags)
  get_button(container).tags = tags
end

function this.set_tooltip(container, tooltip)
  get_button(container).tooltip = tooltip
end

return this
