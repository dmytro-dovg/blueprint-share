data:extend({
  {
    type = "int-setting",
    name = "blueprint-share-destination-port",
    setting_type = "runtime-per-user",
    default_value = 25002,
    minimum_value = 1024,
    maximum_value = 65535,
  },
  {
    type = "bool-setting",
    name = "blueprint-share-debug",
    setting_type = "runtime-per-user",
    default_value = false
  },
})