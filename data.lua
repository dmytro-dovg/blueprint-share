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

data:extend({
  send_input,
  receive_input,
})
