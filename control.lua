
function debug_print(msg, player_index)
  local message = "blueprint-share: debug: " .. msg
  log(message)
  if not player_index then
    return
  end
  local debug_enabled = settings.get_player_settings(player_index)["blueprint-share-debug"].value
  if not debug_enabled then
    return
  end
  game.get_player(player_index).print(message, { sound = defines.print_sound.never })
end

function send_payload(port, payload)
  local json = helpers.table_to_json({
    game_version = helpers.game_version,
    mod_version = script.active_mods["blueprint-share"],
    payload = payload
  })
  helpers.send_udp(port, json)
end

-- Poll UDP buffer every 10 ticks (~166ms at 60 UPS)
script.on_nth_tick(10, function()
  helpers.recv_udp()
end)

script.on_event(defines.events.on_udp_packet_received, function(event)
  local player_index = event.player_index
  local player = game.get_player(player_index)
  if not player then return end
  debug_print("received on port: " ..  event.source_port, player_index)
  player.print({"blueprint-share.blueprint-received"})
  local decoded = helpers.json_to_table(event.payload)
  if not decoded or not decoded.payload then
    player.print({"blueprint-share.error-invalid-payload"})
    return
  end
  debug_print("other client:\n    Factorio " .. decoded.game_version .. "\n    blueprint-share " .. decoded.mod_version, player_index)
  if helpers.compare_versions(helpers.game_version, decoded.game_version) ~= 0 then
    player.print({"blueprint-share.warning-version-mismatch", helpers.game_version, decoded.game_version})
  end
  local success, err = pcall(function()
    player.cursor_stack.import_stack(decoded.payload)
  end)

  if not success then
    debug_print("import failed: " .. tostring(err), player_index)
    player.print({"blueprint-share.error-import-failed"})
  end
end)

script.on_event("blueprint-share-send", function(event)
  local player_index = event.player_index
  local send_port = settings.get_player_settings(player_index)["blueprint-share-destination-port"].value
  local player = game.get_player(player_index)
  local stack = player.cursor_stack
  local record = player.cursor_record
  if record then
    debug_print("record type: " .. record.type, player_index)
    player.print({"blueprint-share.sent", send_port})
    send_payload(send_port, record.export_record())
  else
    if not (stack and stack.valid_for_read and (stack.is_blueprint or stack.is_blueprint_book or stack.is_deconstruction_item or stack.is_upgrade_item)) then
      player.print({"blueprint-share.hold-blueprint"})
      return
    end
    debug_print("stack type: " .. stack.type, player_index)
    send_payload(send_port, stack.export_stack())
    player.print({"blueprint-share.sent", send_port})
  end
end)  