FragmentedData = {}
FragmentedData.__index = FragmentedData

function FragmentedData.new(data, identifier)
  local self = setmetatable({}, FragmentedData)
  local chunks = {}

  -- Each data packet is encoded as:
  --   {"id":<id>,"index":<index>,"total":<total>,"data":"<chunk>"}
  -- Fixed punctuation/keys = 35 bytes.
  -- Integer fields are bounded by their decimal width:
  --   id:    up to 10 digits (math.random max 2^32)
  --   index: up to 7 digits (= max chunks we'd ever produce)
  --   total: same as index
  local target_encoded = 4096
  local envelope = 35 + 10 + 7 + 7
  local safety = 8
  local chunk_size = target_encoded - envelope - safety

  self.total = math.ceil(#data / chunk_size)
  self.index = 0  -- 0 means metachunk not sent yet

  self.metachunk = {
    game_version = helpers.game_version,
    mod_version  = script.active_mods["blueprint-share"],
    id = identifier,
    total = self.total,
  }

  self.chunks = {}
  for i = 1, self.total do
    self.chunks[i] = {
      id = identifier,
      index = i,
      total = self.total,
      data = data:sub((i - 1) * chunk_size + 1, i * chunk_size),
    }
  end
  return self
end

function FragmentedData:next()
  if self.index == 0 then
    self.index = 1
    return self.metachunk
  end
  if self.index > self.total then
    return nil
  end
  local chunk = self.chunks[self.index]
  self.index = self.index + 1
  return chunk
end

return FragmentedData
