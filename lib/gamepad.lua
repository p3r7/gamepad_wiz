-- shim for norns where core/gamepad wasn't yet available

local hid_events = require "hid_events"

gamepad = {}


-- -------------------------------------------------------------------------

function gamepad.axis_code_2_keycode(code)
  local mapping = {
    [0x00] = 'ABS_X',
    [0x01] = 'ABS_Y',
    [0x02] = 'ABS_Z',
    [0x03] = 'ABS_RX',
    [0x04] = 'ABS_RY',
    [0x05] = 'ABS_RZ',
    [0x10] = 'ABS_HAT0X',
    [0x11] = 'ABS_HAT0Y',
  }
  return mapping[code]
end

function gamepad.is_axis_keycode_analog(evt)
  return tab.contains({'ABS_Y', 'ABS_X',
                       'ABS_RY', 'ABS_RX',
                       'ABS_Z', 'ABS_RZ',}, evt)
end

function gamepad.is_analog_origin(gamepad_conf, axis_keycode, value)
  local origin = gamepad_conf.analog_axis_o[axis_keycode]
  if origin == nil then
    origin = 0
  end
  local noize_margin = gamepad_conf.analog_axis_o_margin[axis_keycode]
  if noize_margin == nil then
    noize_margin = 0
  end
  return ( value >= (origin - noize_margin) and value <= (origin + noize_margin))
end


-- -------------------------------------------------------------------------

return gamepad
