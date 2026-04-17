local destination_port = {
  type = "int-setting",
  name = "blueprint-share-destination-port",
  setting_type = "runtime-per-user",
  default_value = 25002,
  minimum_value = 1024,
  maximum_value = 65535,
}

local debug = {
  type = "bool-setting",
  name = "blueprint-share-debug",
  setting_type = "runtime-per-user",
  default_value = false
}

local auto_receive = {
  type = "bool-setting",
  name = "blueprint-share-auto-receive",
  setting_type = "runtime-per-user",
  default_value = true,
}

data:extend({
  auto_receive,
  destination_port,
  debug,
})
