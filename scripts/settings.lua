local Settings = {}

function Settings.auto_receive(player)
    return settings.get_player_settings(player.index)["blueprint-share-auto-receive"].value
end

function Settings.log_level(player)
    return settings.get_player_settings(player.index)["blueprint-share-log-level"].value
end

function Settings.destination_port(player)
    return settings.get_player_settings(player.index)["blueprint-share-destination-port"].value
end

return Settings
