local Settings = require "scripts.settings"
local Log = require "scripts.log"
local Util = require "scripts.util"
local Inbox = require "scripts.gui.inbox"
local FragmentedData = require "scripts.fragmented_data"
local Reassembler = require "scripts.reassembler"

-- Initialisation

local pending = {}
local reassemblers = {}

local function init_player(player)
  storage.players[player.index] = storage.players[player.index] or {}
  local player_storage = storage.players[player.index]
  player_storage.inbox_inventory = player_storage.inbox_inventory or game.create_inventory(Settings.inbox_capacity(player))
  Inbox.init(player)
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
  local player = Util.valid_player(event)
  if player then
    Inbox.cleanup(player)
  end
  if not storage.players then return end
  local player_storage = storage.players[event.player_index]
  if player_storage and player_storage.inbox_inventory and player_storage.inbox_inventory.valid then
    player_storage.inbox_inventory.destroy()
  end
  storage.players[event.player_index] = nil
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  Inbox.on_runtime_mod_setting_changed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
  Inbox.on_click(event)
end)

script.on_event("blueprint-share-toggle-inbox", function(event)
  Inbox.toggle(event)
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  Inbox.on_shortcut(event)
end)

-- Receiving

-- Poll UDP buffer every 10 ticks (~166ms at 60 UPS)
-- Factorio's UDP sockets are bound to 127.0.0.1 only, so this only receives
-- packets sent to localhost on the same machine.
script.on_nth_tick(10, function(event)
  -- Skip on headless server with no players connected (causes engine crash)
  if game.is_multiplayer() and #game.connected_players == 0 then
    return
  end

  -- Clean up reassemblers that have not received packets recently
  local invalidated = {}
  for i, reassembler in pairs(reassemblers) do
    if reassembler.last_tick + 120 < event.tick then
      invalidated[#invalidated + 1] = i
    end
  end

  for _, id in pairs(invalidated) do
    reassemblers[id] = nil
  end

  -- Check UDP buffer
  helpers.recv_udp()
end)

script.on_event(defines.events.on_tick, function(event)
  if next(pending) == nil then return end

  -- Send 1 packet per tick not to overflow receive buffer
  for player_index, item in pairs(pending) do
    local next_packet = item.data:next()
    if next_packet then
      local success, err = pcall(function()
        helpers.send_udp(item.port, helpers.table_to_json(next_packet))
      end)

      if not success then
        pending[player_index] = nil
        local player = game.get_player(player_index)
        if not player or not player.valid then return end
        Log.debug("Failed to send: " .. tostring(err), player)
        Log.error({"blueprint-share.error-failed-to-send", item.type_name, item.port}, player)
      end
    else
      pending[player_index] = nil
      local player = game.get_player(player_index)
      if not player or not player.valid then return end
      Log.info({"blueprint-share.sent", item.type_name, item.port}, player)
    end
  end
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

  local decoded = helpers.json_to_table(event.payload)

    -- Do a version check. This is only performed on "metachunk".
  if decoded and decoded.game_version and decoded.mod_version then
    Log.debug("Player: " .. player.name .. "(" .. player.index .. ")", player)
    Log.debug("Began receiving on port: " ..  event.source_port, player)
    if helpers.compare_versions(helpers.game_version, decoded.game_version) ~= 0 then
      Log.warn({"blueprint-share.warning-version-mismatch", helpers.game_version, decoded.game_version}, player)
    end
    if helpers.compare_versions(script.active_mods["blueprint-share"], decoded.mod_version) ~= 0 then
      Log.warn({"blueprint-share.warning-mod-version-mismatch", script.active_mods["blueprint-share"], decoded.mod_version}, player)
    end
  end

  if not decoded or not decoded.id or not decoded.total or 
     type(decoded.total) ~= "number" or decoded.total < 1 then
    Log.debug("Invalid payload: " .. tostring(event.payload), player)
    Log.error({"blueprint-share.error-invalid-payload"}, player)
    return
  end

  local reassembler = reassemblers[decoded.id]
  if not reassembler then
    reassembler = Reassembler.new(decoded, event.tick)
    reassemblers[decoded.id] = reassembler
  end

  if reassembler:reassemble(decoded, event.tick) then
    Log.debug("Received on port: " ..  event.source_port, player)
    local data = reassembler:data()

    -- Always import if triggered manually.
    -- Otherwise check auto-receive setting during polling.
    if auto_receive or is_manual_trigger then
      Log.debug("Received due to " .. (is_manual_trigger and "manual trigger" or "auto-receive setting"), player)
      import_payload(data, player)
    end
    Inbox.process_payload(data, player)
    reassemblers[decoded.id] = nil
  end
end)

-- Sending

script.on_event("blueprint-share-send", function(event)
  local player = Util.valid_player(event)
  if not player then return end

  local data, localised_type_name = Util.export_cursor_data(player)

  -- Item held is not valid
  if not data or not localised_type_name then
    Log.info({"blueprint-share.hold-blueprint"}, player)
    return
  end

  if not pending[player.index] then
    pending[player.index] = {
      data = FragmentedData.new(data, math.random(1, 2^32)),
      port = Settings.destination_port(player),
      type_name = localised_type_name
    }
  else
    Log.warn({"blueprint-share.warning-pending-transfer", pending[player.index].type_name}, player)
  end
end)
