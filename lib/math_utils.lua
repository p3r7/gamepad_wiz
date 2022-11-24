
local math_utils = {}


-- ------------------------------------------------------------------------
-- basic

function math_utils.round(v)
  return math.floor(v+0.5)
end

function math_utils.min(samples)
  local min = 0
  for _, v in pairs(samples) do
    if v < min then
      min = v
    end
  end
  return min
end

function math_utils.max(samples)
  local max = 0
  for _, v in pairs(samples) do
    if v > max then
      max = v
    end
  end
  return max
end


-- ------------------------------------------------------------------------
-- stats

-- partly stolen from http://lua-users.org/wiki/SimpleStats

function math_utils.mean(samples)
  local sum = 0
  local count= 0
  for _, v in pairs(samples) do
    sum = sum + v
    count = count + 1
  end
  return (sum / count)
end

function math_utils.modes(samples)
  local counts={}

  for k, v in pairs(samples) do
    if counts[v] == nil then
      counts[v] = 1
    else
      counts[v] = counts[v] + 1
    end
  end

  local biggestCount = 0

  for k, v  in pairs( counts ) do
    if v > biggestCount then
      biggestCount = v
    end
  end

  local modes={}

  for k,v in pairs( counts ) do
    if v == biggestCount then
      table.insert( temp, k )
    end
  end

  return modes
end

function math_utils.mode(samples)
  return math_utils.mean(math_utils.modes(samples))
end

-- maximum outlier from ref_value
function math_utils.max_offset_from(samples, ref_value)
  local max_offset = 0

  for _, v in ipairs(samples) do
    local offset = math_utils.round(math.abs(v - ref_value))
    if offset > max_offset then
      max_offset = offset + 2 -- we take some margin
    end
  end

  return max_offset
end

-- maximum outlier from center_weighted value (mode)
function math_utils.max_offset(samples)
  local mode = math_utils.mode(samples)
  return math_utils.max_offset_from(samples, mode)
end


-- ------------------------------------------------------------------------

return math_utils
