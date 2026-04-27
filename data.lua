require "prototypes.styles"
require "prototypes.graphics"
require "prototypes.shortcuts"

local send_input = {
  type = "custom-input",
  name = "blueprint-share-send",
  key_sequence = "CONTROL + B",
}

local receive_input = {
  type = "custom-input",
  name = "blueprint-share-receive",
  key_sequence = "CONTROL + R",
}

local toggle_inbox_input = {
  type = "custom-input",
  name = "blueprint-share-toggle-inbox",
  key_sequence = "CONTROL + SHIFT + B",
}

data:extend({
  send_input,
  receive_input,
  toggle_inbox_input,
})
