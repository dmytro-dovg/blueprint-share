
local function debug_print(msg, player_index)
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

local function send_payload(payload, player_index)
  local json = helpers.table_to_json({
    game_version = helpers.game_version,
    mod_version = script.active_mods["blueprint-share"],
    payload = payload
  })
  local port = settings.get_player_settings(player_index)["blueprint-share-destination-port"].value
  local player = game.get_player(player_index)
  player.print({"blueprint-share.sent", port})
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

local valid_stack_types = {
  ["blueprint"] = true,
  ["blueprint-book"] = true,
  ["deconstruction-item"] = true,
  ["upgrade-item"] = true,
}

local valid_record_types = {
  ["blueprint"] = true,
  ["blueprint-book"] = true,
  ["deconstruction-planner"] = true,
  ["upgrade-planner"] = true,
}

local function get_data_and_type(player)
  if not player then
    return
  end

  -- Determine what the player is holding
  local record = player.cursor_record
  local stack = player.cursor_stack

  -- Record from blueprint library
  if record and valid_record_types[record.type] then
    return record.export_record(), record.type
  end
  
  -- Stack from cursor
  if stack and stack.valid_for_read and valid_stack_types[stack.type] then
    return stack.export_stack(), stack.type
  end
end

script.on_event("blueprint-share-send", function(event)
  local player_index = event.player_index
  local player = game.get_player(player_index)

  -- Cursor is empty
  if player.is_cursor_empty() then
    player.print({"blueprint-share.hold-blueprint"})
    return
  end

  local data, item_type = get_data_and_type(player)

  -- Item held is not valid
  if not data or not item_type then
    player.print({"blueprint-share.hold-blueprint"})
    return
  end

  debug_print("item type: " .. item_type, player_index)
  send_payload(data, player_index)
end)
