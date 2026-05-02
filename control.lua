local Settings = require "scripts.settings"
local Log = require "scripts.log"
local Util = require "scripts.util"
local Inbox = require "scripts.gui.inbox"
local Fragmenter = require "scripts.fragmenter"
local Defragmenter = require "scripts.defragmenter"

-- Initialisation

local pending = {}
local defragmenters = {}
local progress_bar_chunk_threshold = 10
local target_chunk_size = 4096
local chunk_size = Fragmenter.chunk_size(target_chunk_size)

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

  -- Clean up defragmenters that have not received packets recently
  local invalidated = {}
  for player_index, by_id in pairs(defragmenters) do
    for id, defragmenter in pairs(by_id) do
      if defragmenter.last_tick + 120 < event.tick then
        invalidated[#invalidated + 1] = { player_index = player_index, id = id }
      end
    end
  end

  for _, entry in pairs(invalidated) do
    local by_id = defragmenters[entry.player_index]
    by_id[entry.id] = nil
    if not next(by_id) then
      defragmenters[entry.player_index] = nil
    end
    local player = game.get_player(entry.player_index)
    if player then
      Inbox.clear_progress(player)
    end
  end

  -- Check UDP buffer
  helpers.recv_udp()
end)

local function on_tick_handler(event)
  if next(pending) == nil then
    script.on_event(defines.events.on_tick, nil)
    return
  end

  -- Send 1 packet per tick not to overflow receive buffer
  for player_index, item in pairs(pending) do
    local next_packet = item.data:next()
    if next_packet then
      local success, err = pcall(function()
        helpers.send_udp(item.port, helpers.table_to_json(next_packet), player_index)
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
end

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

  if not decoded or not decoded.id or not decoded.total or 
     type(decoded.total) ~= "number" or decoded.total < 1 then
    Log.debug("Invalid payload: " .. tostring(event.payload), player)
    Log.error({"blueprint-share.error-invalid-payload"}, player)
    return
  end

  -- Do a version check. This is only performed on "metachunk".
  if decoded.game_version and decoded.mod_version then
    Log.debug("Player: " .. player.name .. "(" .. player.index .. ")", player)
    Log.debug("Began receiving on port: " ..  event.source_port, player)
    if helpers.compare_versions(helpers.game_version, decoded.game_version) ~= 0 then
      Log.warn({"blueprint-share.warning-version-mismatch", helpers.game_version, decoded.game_version}, player)
    end
    if helpers.compare_versions(script.active_mods["blueprint-share"], decoded.mod_version) ~= 0 then
      Log.warn({"blueprint-share.warning-mod-version-mismatch", script.active_mods["blueprint-share"], decoded.mod_version}, player)
    end
  end

  -- Reject oversized transfers before any buffering. The receiver does not push data to
  -- synced game state until a transfer completes, so capping size here keeps a malicious
  -- sender from forcing the receiver to relay a huge blueprint to the multiplayer server.
  local max_kib = Settings.max_transfer_size_kib()
  local size_limit = nil
  if max_kib > 0 then
    size_limit = max_kib * 1024
    local max_chunks = math.ceil(size_limit / chunk_size)
    if decoded.total > max_chunks then
      if decoded.game_version and decoded.mod_version then
        Log.error({"blueprint-share.error-transfer-too-large", max_kib}, player)
      end
      Log.debug("Rejected transfer id " .. tostring(decoded.id) .. ": total=" .. decoded.total .. " exceeds " .. max_chunks .. " chunks", player)
      return
    end
  end

  local by_id = defragmenters[player.index] or {}
  defragmenters[player.index] = by_id

  local defragmenter = by_id[decoded.id]
  if not defragmenter then
    -- This player already has a transfer in progress
    if next(by_id) then
      return
    end
    defragmenter = Defragmenter.new(decoded, event.tick, size_limit, chunk_size)
    by_id[decoded.id] = defragmenter
  end

  if defragmenter:add(decoded, event.tick) then
    Log.debug("Received on port: " ..  event.source_port, player)
    local data = defragmenter:data()

    -- Always import if triggered manually.
    -- Otherwise check auto-receive setting during polling.
    if auto_receive or is_manual_trigger then
      Log.debug("Received due to " .. (is_manual_trigger and "manual trigger" or "auto-receive setting"), player)
      import_payload(data, player)
    end
    Inbox.process_payload(data, player)
    by_id[decoded.id] = nil
    if not next(by_id) then
      defragmenters[player.index] = nil
    end
  end

  if defragmenter.total > progress_bar_chunk_threshold then
    Inbox.set_progress(defragmenter:progress(), player)
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

  -- Refuse to send anything the receiver would reject anyway.
  local max_kib = Settings.max_transfer_size_kib()
  if max_kib > 0 and #data > max_kib * 1024 then
    Log.error({"blueprint-share.error-send-too-large", localised_type_name, max_kib}, player)
    return
  end

  if not pending[player.index] then
    pending[player.index] = {
      data = Fragmenter.new(data, math.random(1, 2^32), chunk_size),
      port = Settings.destination_port(player),
      type_name = localised_type_name
    }

    script.on_event(defines.events.on_tick, on_tick_handler)
  else
    Log.warn({"blueprint-share.warning-pending-transfer", pending[player.index].type_name}, player)
  end
end)
