
local string_utils = {}


-- ------------------------------------------------------------------------
-- utils

function string_utils.truncate(txt, size)
  if string.len(txt) > size then
    s1 = string.sub(txt, 1, 9) .. "..."
    s2 = string.sub(txt, string.len(txt) - 5, string.len(txt))
    s = s1..s2
  else
    s = txt
  end
  return s
end

function string_utils.trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end


-- ------------------------------------------------------------------------

return string_utils
