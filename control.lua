received_buffer = {}

-- Also used for mapping stack types to prototype names for l10n
local valid_stack_types = {
  ["blueprint"] = "blueprint",
  ["blueprint-book"] = "blueprint-book",
  ["deconstruction-item"] = "deconstruction-planner",
  ["upgrade-item"] = "upgrade-planner",
}

local valid_record_types = {
  ["blueprint"] = true,
  ["blueprint-book"] = true,
  ["deconstruction-planner"] = true,
  ["upgrade-planner"] = true,
}

local function debug_print(msg, player)
  local message = "blueprint-share: debug: " .. msg
  log(message)
  if not player then
    return
  end
  local debug_enabled = settings.get_player_settings(player.index)["blueprint-share-debug"].value
  if not debug_enabled then
    return
  end
  player.print(message, { sound = defines.print_sound.never })
end

local function guard_player(event)
  local player_index = event.player_index
  if player_index == 0 then
    debug_print("server receiving data is unsupported")
    return
  end

  local player = game.get_player(player_index)
  if not player then
    debug_print("no player")
    return
  end
  return player
end

local function get_data_and_type(player)
  if not player then
    return
  end

  -- Determine what the player is holding
  local record = player.cursor_record
  local stack = player.cursor_stack

  -- Record from blueprint library
  if record and valid_record_types[record.type] then
    return record.export_record(), {"item-name." .. record.type}
  end

  -- Stack from cursor
  if stack and stack.valid_for_read and valid_stack_types[stack.type] then
    return stack.export_stack(), {"item-name." .. valid_stack_types[stack.type]}
  end
end

local function send_payload(payload, port)
  local json = helpers.table_to_json({
    game_version = helpers.game_version,
    mod_version = script.active_mods["blueprint-share"],
    payload = payload
  })

  helpers.send_udp(port, json)
end


-- Receiving

-- Poll UDP buffer every 10 ticks (~166ms at 60 UPS)
-- Factorio's UDP sockets are bound to 127.0.0.1 only, so this only receives
-- packets sent to localhost on the same machine.
script.on_nth_tick(10, function()
  -- Skip on headless server with no players connected (causes engine crash)
  if game.is_multiplayer() and #game.connected_players == 0 then
    return
  end

  -- Check UDP buffer
  helpers.recv_udp()
end)

function import_from_buffer(player)
  local payload = received_buffer[player.index]
  if payload then
    player.cursor_stack.import_stack(payload)
    -- Clear bufferred item
    received_buffer[player.index] = nil
  end
end

script.on_event("blueprint-share-receive", function(event)
  local player = guard_player(event)
  if not player then return end

  debug_print("Manually receiving", player)
  import_from_buffer(player)
end)

script.on_event(defines.events.on_udp_packet_received, function(event)
  local player = guard_player(event)
  if not player then return end

  debug_print("on_udp_packet_received", player)

  debug_print("player: " .. player.name .. "(" .. player.index .. ")", player)
  debug_print("received on port: " ..  event.source_port, player)

  local decoded = helpers.json_to_table(event.payload)
  if not decoded or not decoded.payload then
    debug_print("invalid payload: " .. tostring(event.payload), player)
    player.print({"blueprint-share.error-invalid-payload"})
    return
  end

  debug_print("other client:\n    Factorio " .. decoded.game_version .. "\n    blueprint-share " .. decoded.mod_version, player)

  if helpers.compare_versions(helpers.game_version, decoded.game_version) ~= 0 then
    player.print({"blueprint-share.warning-version-mismatch", helpers.game_version, decoded.game_version})
  end

  local success, err = pcall(function()
    received_buffer[player.index] = decoded.payload
  end)

  local auto_receive = settings.get_player_settings(player.index)["blueprint-share-auto-receive"].value
  if auto_receive then
    debug_print("Auto-receiving", player)
    import_from_buffer(player)
  end

  if success then
    player.print({"blueprint-share.blueprint-received", player.cursor_stack.prototype.localised_name})
  else
    debug_print("import failed: " .. tostring(err), player)
    player.print({"blueprint-share.error-import-failed"})
  end
end)

-- Sending
script.on_event("blueprint-share-send", function(event)
  local player = guard_player(event)
  if not player then return end

  -- Cursor is empty
  if player.is_cursor_empty() then
    player.print({"blueprint-share.hold-blueprint"})
    return
  end

  local data, localised_type_name = get_data_and_type(player)

  -- Item held is not valid
  if not data or not localised_type_name then
    player.print({"blueprint-share.hold-blueprint"})
    return
  end

  local port = settings.get_player_settings(player.index)["blueprint-share-destination-port"].value
  send_payload(data, port)
  player.print({"blueprint-share.sent", localised_type_name, port})
end)
