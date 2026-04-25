local Settings = require "scripts.settings"
local Log = require "scripts.log"
local Config = require "scripts.config"
local Util = require "scripts.util"
local Inbox = require "scripts.gui.inbox"

-- Initialisation

local function init_player(player)
  storage.players[player.index] = storage.players[player.index] or {}
  local player_storage = storage.players[player.index]
  player_storage.inbox_inventory = player_storage.inbox_inventory or game.create_inventory(Settings.inbox_capacity(player))
end

script.on_init(function()
  storage.players = {}
  for _, player in pairs(game.players) do
    init_player(player)
  end
end)

script.on_configuration_changed(function()
  storage.players = storage.players or {}
  for _, player in pairs(game.players) do
    init_player(player)
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  init_player(game.get_player(event.player_index))
end)

script.on_event(defines.events.on_player_removed, function(event)
  local player_storage = storage.players[event.player_index]
  if player_storage and player_storage.inbox_inventory and player_storage.inbox_inventory.valid then
    player_storage.inbox_inventory.destroy()
  end
  storage.players[event.player_index] = nil
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "blueprint-share-inbox-capacity" and event.setting_type == "runtime-per-user" then
    local player = Util.valid_player(event)
    if not player then return end
    Inbox.resize(player, Settings.inbox_capacity(player))
    Inbox.refresh(player)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  Inbox.on_click(event)
end)

script.on_event("blueprint-share-toggle-inbox", function(event)
  Inbox.toggle(event)
end)

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

local function import_payload(payload, player)
  if payload and player.cursor_stack and player.cursor_stack.valid then
    local result = player.cursor_stack.import_stack(payload)
    if result <= 0 then
      -- This will make the item disappear if player dismisses it
      player.cursor_stack_temporary = true
      local name = player.cursor_stack.valid_for_read and player.cursor_stack.prototype.localised_name or {"blueprint-share.unknown-item"}
      if result == 0 then
        Log.info({"blueprint-share.blueprint-received", name}, player)
      else
        Log.warn({"blueprint-share.blueprint-received-with-warnings", name}, player)
      end
    else
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
    ), player)

  if helpers.compare_versions(helpers.game_version, decoded.game_version) ~= 0 then
    Log.warn({"blueprint-share.warning-version-mismatch", helpers.game_version, decoded.game_version}, player)
  end

  -- Always import if triggered manually.
  -- Otherwise check auto-receive setting during polling.
  if auto_receive or is_manual_trigger then
    Log.debug("Received due to " .. (is_manual_trigger and "manual trigger" or "auto-receive setting"), player)
    import_payload(decoded.payload, player)
  end
  Inbox.process_payload(decoded.payload, player)
  Inbox.update(player)
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
    helpers.send_udp(port, json, player.index)
  end)

  if success then
    Log.info({"blueprint-share.sent", localised_type_name, port}, player)
  else
    Log.debug("Failed to send: " .. tostring(err), player)
    Log.error({"blueprint-share.error-failed-to-send", localised_type_name, port}, player)
  end
end)
