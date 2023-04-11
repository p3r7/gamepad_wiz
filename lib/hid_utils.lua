
local hid_utils = {}
local hid_events = require "hid_events"


-- ------------------------------------------------------------------------
-- deps

local hid_events = require "hid_events"


-- ------------------------------------------------------------------------
-- state

hid_utils.hdevs = {}
hid_utils.devicepos = 1
hid_utils.hid_device = nil


function hid_utils.lookup()
  hid_utils.hdevs = {}
  for id,device in pairs(hid.vports) do
    hid_utils.hdevs[id] = device.name
  end
end

function hid_utils.print()
  print ("HID Devices:")
  for id,device in pairs(hid.vports) do
    hid_utils.hdevs[id] = device.name
    print(id, hid_utils.hdevs[id])
  end
end

function hid_utils.name_current()
  return hid_utils.hdevs[hid_utils.devicepos]
end

function hid_utils.guid_current()
  return hid_utils.hid_device.guid
end

function hid_utils.pos_current()
  return hid_utils.devicepos
end

function hid_utils.connect_current(cb)
  hid.update_devices()
  hid_utils.hid_device = hid.connect(hid_utils.devicepos)
  hid_utils.hid_device.event = cb
end


-- ------------------------------------------------------------------------
-- PARAM

function hid_utils.param_options()
  return hid_utils.hdevs
end

function hid_utils.param_action(param, devicepos, cb)
  hid_utils.hid_device.event = nil

  hid_utils.devicepos = devicepos
  hid_utils.connect_current(cb)

  hid_utils.lookup()

  local param_id = params.lookup[param]
  params.params[param_id].options = hid_utils.hdevs
  --tab.print(params.params[1].options)

  -- print("hid ".. devicepos .." selected: " .. hid_utils.hdevs[devicepos])
end

function hid_utils.enc(param, d)
  params:set(param, util.clamp(hid_utils.pos_current() + d, 1, 4))
end


-- ------------------------------------------------------------------------
-- low-level

function hid_utils.event_type_code(event_type)
  for k, v in pairs(hid_events.types) do
    if tonumber(v) == event_type then
      return k
    end
  end
end


-- ------------------------------------------------------------------------

return hid_utils
