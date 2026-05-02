local Defragmenter = {}
Defragmenter.__index = Defragmenter

function Defragmenter.new(chunk, tick, total_size_limit, chunk_size_limit)
  local self = setmetatable({}, Defragmenter)
  self.chunks = {}
  self.id = chunk.id
  self.total = chunk.total
  self.chunks_received = 0
  self.bytes_received = 0
  self.last_tick = tick
  -- nil - unlimited
  self.total_size_limit = total_size_limit
  self.chunk_size_limit = chunk_size_limit
  return self
end

function Defragmenter:add(chunk, tick)
  if chunk.id ~= self.id then
    return false
  end

  -- Validation
  if not chunk.data or not chunk.index or type(chunk.data) ~= "string" then return false end

  -- Do not process chunks that are too big
  if self.chunk_size_limit and #chunk.data > self.chunk_size_limit then return false end

  local index = chunk.index
  if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > self.total then
    return false
  end

  -- Duplicate chunk
  if self.chunks[index] then return false end

  if self.total_size_limit and self.bytes_received + #chunk.data > self.total_size_limit then return false end

  self.chunks[index] = chunk.data
  self.bytes_received = self.bytes_received + #chunk.data
  self.chunks_received = self.chunks_received + 1
  self.last_tick = tick
  if self.chunks_received == self.total then
    return true
  end
  return false
end

function Defragmenter:data()
  if self.chunks_received == self.total then
    local ordered = {}
    for i, v in ipairs(self.chunks) do
      ordered[i] = v
    end
    return table.concat(ordered)
  end
end

function Defragmenter:progress()
  return self.total > 0 and self.chunks_received / self.total or 0
end

return Defragmenter
