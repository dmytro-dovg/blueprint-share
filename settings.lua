local destination_port = {
  type = "int-setting",
  name = "blueprint-share-destination-port",
  setting_type = "runtime-per-user",
  default_value = 25002,
  minimum_value = 1024,
  maximum_value = 65535,
}

local log_level = {
  type = "string-setting",
  name = "blueprint-share-log-level",
  setting_type = "runtime-per-user",
  allowed_values = {"debug", "info", "warn", "error", "quiet"},
  default_value = "info",
}

local auto_receive = {
  type = "bool-setting",
  name = "blueprint-share-auto-receive",
  setting_type = "runtime-per-user",
  default_value = true,
}

local inbox_capacity = {
  type = "int-setting",
  name = "blueprint-share-inbox-capacity",
  setting_type = "runtime-per-user",
  default_value = 5,
  minimum_value = 1,
  maximum_value = 16,
}

local show_mod_gui_button = {
  type = "bool-setting",
  name = "blueprint-share-show-mod-gui-button",
  setting_type = "runtime-per-user",
  default_value = true,
}

data:extend({
  auto_receive,
  destination_port,
  log_level,
  inbox_capacity,
  show_mod_gui_button,
})
