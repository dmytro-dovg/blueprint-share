local Settings = {}

local mod_prefix = "blueprint-share-"

local function get(player, key)
  return settings.get_player_settings(player.index)[mod_prefix .. key].value
end

function Settings.auto_receive(player)
  return get(player, "auto-receive")
end

function Settings.log_level(player)
  return get(player, "log-level")
end

function Settings.destination_port(player)
  return get(player, "destination-port")
end

function Settings.inbox_size(player)
  return get(player, "inbox-size")
end

return Settings
