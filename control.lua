local Settings = require "scripts.settings"
local Log = require "scripts.log"
local Config = require "scripts.config"
local Util = require "scripts.util"

local received_buffer = {}

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

local function import_from_buffer(player)
  local payload = received_buffer[player.index]
  if payload then
    local success, err = pcall(function()
      player.cursor_stack.import_stack(payload)
    end)

    -- Clear buffered item
    received_buffer[player.index] = nil

    if success then
      local name = (player.cursor_stack and player.cursor_stack.valid_for_read) and player.cursor_stack.prototype.localised_name or {"blueprint-share.unknown-item"}
      Log.info({"blueprint-share.blueprint-received", name}, player)
    else
      Log.debug("Import failed: " .. tostring(err), player)
      Log.error({"blueprint-share.error-import-failed"}, player)
    end
  end
end

script.on_event("blueprint-share-receive", function(event)
  local player = Util.valid_player(event)
  if not player then return end

  Log.debug("Manually receiving", player)
  if game.tick_paused then
    Log.debug("Game paused, manually checking UDP buffer.", player)
    helpers.recv_udp()
  else
    import_from_buffer(player)
  end
end)

script.on_event(defines.events.on_udp_packet_received, function(event)
  local player = Util.valid_player(event)
  if not player then return end

  -- Polling is skipped while paused, so a received packet must be from the manual trigger.
  -- on_nth_tick doesn't fire while paused, so a packet arriving in this state can only be from
  -- the manual hotkey's direct recv_udp() call.
  local is_manual_trigger = game.tick_paused
  local auto_receive = Settings.auto_receive(player)

  Log.debug("Player: " .. player.name .. "(" .. player.index .. ")", player)
  Log.debug("Received on port: " ..  event.source_port, player)

  local decoded = helpers.json_to_table(event.payload)
  if not decoded or not decoded.payload or not decoded.game_version or not decoded.mod_version then
    Log.debug("Invalid payload: " .. tostring(event.payload), player)
    Log.error({"blueprint-share.error-invalid-payload"}, player)
    return
  end

  Log.debug(string.format(
    "Received from:\n    Factorio %s\n    blueprint-share %s",
    decoded.game_version, decoded.mod_version 
    , player))

  if helpers.compare_versions(helpers.game_version, decoded.game_version) ~= 0 then
    Log.warn({"blueprint-share.warning-version-mismatch", helpers.game_version, decoded.game_version}, player)
  end

  received_buffer[player.index] = decoded.payload

  -- Always import if triggered manually.
  -- Otherwise check auto-receive setting during polling.
  if auto_receive or is_manual_trigger then
    Log.debug("Received due to " .. (is_manual_trigger and "manual trigger" or "auto-receive setting"), player)
    import_from_buffer(player)
  end
end)

-- Sending

script.on_event("blueprint-share-send", function(event)
  local player = Util.valid_player(event)
  if not player then return end

  -- Cursor is empty
  if player.is_cursor_empty() then
    Log.info({"blueprint-share.hold-blueprint"}, player)
    return
  end

  local data, localised_type_name = Util.export_cursor_data(player)

  -- Item held is not valid
  if not data or not localised_type_name then
    Log.info({"blueprint-share.hold-blueprint"}, player)
    return
  end

  local json = helpers.table_to_json({
    game_version = helpers.game_version,
    mod_version = script.active_mods["blueprint-share"],
    payload = data
  })
  Log.debug("Payload length: " .. tostring(#json), player)

  -- UDP packets cannot exceed 65535 bytes
  if #json > Config.max_udp_packet_size then
    Log.error({"blueprint-share.error-payload-too-large"}, player)
    return
  end
  local port = Settings.destination_port(player)
  local success, err = pcall(function()
    helpers.send_udp(port, json)
  end)

  if success then
    Log.info({"blueprint-share.sent", localised_type_name, port}, player)
  else
    Log.debug("Failed to send: " .. tostring(err), player)
    Log.error({"blueprint-share.error-failed-to-send", localised_type_name, port}, player)
  end
end)
