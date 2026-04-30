local Defragmenter = {}
Defragmenter.__index = Defragmenter

function Defragmenter.new(chunk, tick)
  local self = setmetatable({}, Defragmenter)
  self.chunks = {}
  self.id = chunk.id
  self.total = chunk.total
  self.received = 0
  self.last_tick = tick
  return self
end

function Defragmenter:add(chunk, tick)
  if chunk.id ~= self.id then
    return false
  end

  -- Validation
  if not chunk.data or not chunk.index or type(chunk.data) ~= "string" then return false end

  local index = chunk.index
  if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > self.total then
    return false
  end

  -- Duplicate chunk
  if self.chunks[index] then return false end

  self.chunks[index] = chunk.data
  self.received = self.received + 1
  self.last_tick = tick
  if self.received == self.total then
    return true
  end
  return false
end

function Defragmenter:data()
  if self.received == self.total then
    local ordered = {}
    for i, v in ipairs(self.chunks) do
      ordered[i] = v
    end
    return table.concat(ordered)
  end
end

return Defragmenter
