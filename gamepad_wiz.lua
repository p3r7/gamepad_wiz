-- gamepad_wiz.
--
-- @eigen

local hid_events = require "hid_events"

local inspect = include('lib/inspect')


-- ------------------------------------------------------------------------
-- conf

local setup_steps = {
  'choose_device',
  'analog_calibration',

  -- 'dpad_up',
  'dpad_down',
  'dpad_left',
  -- 'dpad_right',

  -- 'lstick_up',
  'lstick_down',
  'lstick_left',
  -- 'lstick_right',

  -- 'rstick_up',
  'rstick_down',
  'rstick_left',
  -- 'rstick_right',
}

local buttons = {
  'A',
  'B',
  'X',
  'Y',
  -- 'C',
  -- 'Z',
  'L1',
  'R1',
  'L2',
  'R2',
  'START',
  'SELECT',
}

for _, b in ipairs(buttons) do
  table.insert(setup_steps, b)
end
table.insert(setup_steps, 'confirm')
table.insert(setup_steps, 'end')

-- ------------------------------------------------------------------------
-- state

local devicepos = 1
local hdevs = {}
local hid_device
local msg = {}

local curr_setup_step = 1

local g = {
  hid_name = nil,
  alias = nil,

  button = {},

  dpad_is_analog = false,

  axis_invert = {
  },

  analog_axis_o_magin = {},
  analog_axis_resolution = 256,
}

local function after_step_change()
  local step_name = setup_steps[curr_setup_step]

  if step_name == 'analog_calibration' then
    analog_o_offset_buff = {}
    analog_o_offset_nb_samples = 0
    analog_o_offset_nb_axis = 0
    g.analog_axis_o_magin = {}
  elseif tab.contains(buttons, step_name) then
    g.button[step_name] = nil
  elseif step_name == 'end' then
    print(inspect(g))
  end
end

local function next_step()
  curr_setup_step = curr_setup_step + 1
  after_step_change()
end

local function prev_step()
  curr_setup_step = curr_setup_step - 1
  after_step_change()
end


-- ------------------------------------------------------------------------
-- init

function init()
  connect()
  get_hid_names()
  print_hid_names()

  params:add{type = "option", id = "hid_device", name = "HID-device", options = hdevs , default = 1,
             action = function(value)
               hid_device.event = nil
               --grid.cleanup()
               hid_device = hid.connect(value)
               hid_device.event = hid_event
               hid.update_devices()

               hdevs = {}
               get_hid_names()
               params.params[1].options = hdevs
               --tab.print(params.params[1].options)
               devicepos = value
               if clocking then
                 clock.cancel(blink_id)
                 clocking = false
               end
               print("hid ".. devicepos .." selected: " .. hdevs[devicepos])

  end}


  screen.aa(1)
  screen.line_width(1)
end

local fps = 15
redraw_clock = clock.run(
  function()
    local step_s = 1 / fps
    while true do
      clock.sleep(step_s)
      redraw()
    end
end)

function cleanup()
  clock.cancel(redraw_clock)
end


-- ------------------------------------------------------------------------
-- IO

-- Used to go forward/back during setup
function key(n, z)
  local changed = false

  if n==2 and z == 1 and curr_setup_step > 0 then
    prev_step()
  end
  if n == 3 and z == 1 then
    if setup_steps[curr_setup_step] ~= 'analog_calibration' then
      next_step()
    end
  end
end


-- Only used for 1rst step (device selection)
function enc(id,delta)
  local step_name = setup_steps[curr_setup_step]

  if step_name ~= 'choose_device' then
    return
  end

  if id == 1 then
    --print(params:get("hid_device"))
    params:set("hid_device", util.clamp(devicepos+delta, 1,4))
  end
  if id == 2 then
  end
  if id == 3 then
  end

  -- redraw()
end


-- ------------------------------------------------------------------------
-- COPY-PASTED FROM GAMEPAD LIB

--- Optimized version of `gamepad.code_2_keycode`
function axis_code_2_keycode(code)
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

function direction_event_code_type_to_axis(evt)
  if evt == 'ABS_HAT0Y' or evt == 'ABS_Y' then
    return 'Y'
  elseif evt == 'ABS_HAT0X' or evt == 'ABS_X' then
    return 'X'
  elseif evt == 'ABS_RY' then
    return 'RY'
  elseif evt == 'ABS_RX' then
    return 'RX'
  elseif evt == 'ABS_Z' then
    return 'Z'
  elseif evt == 'ABS_RZ' then
    return 'RZ'
  end
end

function is_direction_event_code_analog(evt)
  return tab.contains({'ABS_Y', 'ABS_X',
                       'ABS_RY', 'ABS_RX',
                       'ABS_Z', 'ABS_RZ',}, evt)
end


-- ------------------------------------------------------------------------
-- HID EVENT CB

local analog_o_offset_buff = {}
local analog_o_offset_nb_axis = 0
local analog_o_offset_nb_samples = 0

local ANALOG_CALIBRATION_SAMPLES_PER_AXIS = 50

local function step_2_axis(step_name)
  if step_name == 'dpad_down' or step_name == 'lstick_down' then
    return 'Y'
  elseif step_name == 'dpad_left' or step_name == 'lstick_left' then
    return 'X'
  elseif step_name == 'rpad_down' then
    return 'RZ'
  elseif step_name == 'rpad_left' then
    return 'Z'
  end
end

function hid_event(typ, code, val)

  local step_name = setup_steps[curr_setup_step]

  local half_reso = g.analog_axis_resolution/2

  local event_code_type
  for k, v in pairs(hid_events.types) do
    if tonumber(v) == typ then
      event_code_type = k
      break
    end
  end

  if event_code_type == "EV_ABS" then
    if step_name == 'analog_calibration' then

      local axis_evt = axis_code_2_keycode(code)
      local axis = direction_event_code_type_to_axis(axis_evt)
      local is_analog = is_direction_event_code_analog(axis_evt)

      if not is_analog then
        return
      end

      if analog_o_offset_buff[axis] == nil then
        analog_o_offset_buff[axis] = {}
        analog_o_offset_nb_axis = analog_o_offset_nb_axis + 1
      end

      table.insert(analog_o_offset_buff[axis], val)
      analog_o_offset_nb_samples = analog_o_offset_nb_samples + 1

      if (analog_o_offset_nb_samples / analog_o_offset_nb_axis) > ANALOG_CALIBRATION_SAMPLES_PER_AXIS then
        local max_offsets = {}
        for axis, samples in ipairs(analog_o_offset_buff) do
          max_offsets[axis] = 0
          for _, v in ipairs(samples) do
            local offset = math.abs(v - half_reso)
            if offset > max_offsets[axis] then
              max_offsets[axis] = offset + 2 -- we take some margin
            end
          end
        end
        g.analog_axis_o_magin = max_offsets
        next_step()
      end
    elseif util.string_starts(step_name, 'dpad_')
      or util.string_starts(step_name, 'lstick_')
      or util.string_starts(step_name, 'rstick_') then

      local tested_axis = step_2_axis(step_name)

      print(step_name.." -> ".. tested_axis)

      local sign = val
      local axis_evt = axis_code_2_keycode(code)
      local axis = direction_event_code_type_to_axis(axis_evt)
      local is_analog = is_direction_event_code_analog(axis_evt)

      if axis ~= tested_axis then
        print("pressed "..axis.." while expected "..tested_axis)
        return
      end

      if is_analog then
        val = val - half_reso
        if val <= half_reso * 2/3 and val >= - half_reso * 2/3 then
          sign = 0
        else
          sign = val < 0 and -1 or 1
        end
      else -- digital
        if sign ~= 0 then
          sign = val < 0 and -1 or 1
        end
      end

      if is_analog and util.string_starts(step_name, 'dpad_') then
        g.dpad_is_analog = true
      end

      if sign ~= 0 then
        if sign < 0 then
          g.axis_invert[tested_axis] = true
        else
          g.axis_invert[tested_axis] = false
        end
        next_step()
      end
    end
  end
  if event_code_type == "EV_KEY"
    and tab.contains(buttons, step_name)
    and val == 0
  then
    g.button[step_name] = code
    next_step()
  end
end


-- ------------------------------------------------------------------------
-- REDRAW

function redraw()
  screen.clear()

  local step_name = setup_steps[curr_setup_step]

  screen.level(15)
  if step_name == 'choose_device' then
    screen.move(0, 7)
    screen.text("choose device")
    screen.move(0, 17)
    screen.text(devicepos .. ": ".. truncate_txt(hdevs[devicepos], 19))
    screen.move(0, 64-10)
    screen.text("E1: select, K3: next")
  elseif step_name == 'analog_calibration' then
    screen.move(0, 7)
    screen.text("calibrating analog inputs")
    screen.move(0, 17)
    screen.text("(" .. analog_o_offset_nb_samples .. "/" .. (ANALOG_CALIBRATION_SAMPLES_PER_AXIS * analog_o_offset_nb_axis) .. ")")
    screen.move(0, 64-10)
    screen.text("K2: prev")
  elseif util.string_starts(step_name, 'dpad_')
    or util.string_starts(step_name, 'lstick_')
    or util.string_starts(step_name, 'rstick_')
    or tab.contains(buttons, step_name) then
    screen.move(0, 7)
    screen.text("press "..step_name)
    screen.move(0, 64-10)
    screen.text("K2: prev, K3: next (skip)")
  elseif step_name == 'confirm' then
    screen.move(0, 7)
    screen.text("generate conf file?")
    screen.move(0, 64-10)
    screen.text("K2: prev, K3: yes")
  else
    screen.move(0, 7)
    screen.text("FINISHED")
  end

  screen.update()
end


-- ------------------------------------------------------------------------
-- HELPER FNS - HID DEVICES

function get_hid_names()
  -- Get a list of grid devices
  for id,device in pairs(hid.vports) do
    hdevs[id] = device.name
  end
end

function print_hid_names()
  print ("HID Devices:")
  for id,device in pairs(hid.vports) do
    hdevs[id] = device.name
    print(id, hdevs[id])
  end
end

function connect()
  hid.update_devices()
  hid_device = hid.connect(devicepos)
  hid_device.event = hid_event
end


-- ------------------------------------------------------------------------
-- HELPER FNS - STR

function truncate_txt(txt, size)
  if string.len(txt) > size then
    s1 = string.sub(txt, 1, 9) .. "..."
    s2 = string.sub(txt, string.len(txt) - 5, string.len(txt))
    s = s1..s2
  else
    s = txt
  end
  return s
end
