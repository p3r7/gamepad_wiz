
local tab_utils = {}


-- ------------------------------------------------------------------------
-- deps

local inspect = include('lib/inspect')


-- ------------------------------------------------------------------------
-- utils

-- NB: tab.save is kinda wacky w/ hashmaps
function tab_utils.save(t, filepath)
  local file, err = io.open(filepath, "wb")
  if err then return err end
  file:write("return "..inspect(t))
  file:close()
end

function tab_utils.keys(t)
  local out = {}
  for k, _ in pairs(t) do
    table.insert(out, k)
  end
  return out
end

function tab_utils.values(t)
  local out = {}
  for _, v in pairs(t) do
    table.insert(out, v)
  end
  return out
end


-- ------------------------------------------------------------------------

return tab_utils
