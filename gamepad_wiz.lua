-- gamepad_wiz.
--
-- @eigen

local hid_events = require "hid_events"


-- ------------------------------------------------------------------------
-- conf

local setup_steps = {
  'choose_device',
  'analog_calibration',

  -- TODO: analog VS dpad
  'dpad_up',
  'dpad_down',
  'dpad_left',
  'dpad_right',
}

local buttons = {
  'A',
  'B',
  'X',
  'Y',
  'C',
  'Z',
  'L1',
  'L2',
  'R1',
  'R2',
  'SELECT',
  'START',
}

for _, b in ipairs(buttons) do
  table.insert(setup_steps, b)
end

-- ------------------------------------------------------------------------
-- state

local devicepos = 1
local hdevs = {}
local hid_device
local msg = {}

local hid_buffer = {}
local hid_buffer_len = 256
local buff_start = 1

local curr_setup_step = 1

local g = {
  hid_name = nil,
  alias = nil,
  button = {
    A = nil,
    B = nil,
    X = nil,
    Y = nil,
    C = nil,
    Z = nil,
    L1 = nil,
    L2 = nil,
    R1 = nil,
    R2 = nil,
    SELECT = nil,
    START = nil,
  },

  dpad_o_margin = 0,
  dpad_resolution = 256,
  dpad_invert = {
    Y = false,
    X = false,
  },
}

-- ------------------------------------------------------------------------
-- init

function init()
  clear_hid_buffer()

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
               print ("hid ".. devicepos .." selected: " .. hdevs[devicepos])

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
    curr_setup_step = curr_setup_step - 1
    changed = true
  end
  if n == 3 and z == 1 then
    if setup_steps[curr_setup_step] ~= 'analog_calibration' then
      curr_setup_step = curr_setup_step + 1
      changed = true
    end
  end

  if changed and setup_steps[curr_setup_step] == 'analog_calibration' then
    analog_o_offset_buff = {}
    analog_o_offset_samples = 0
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
-- HID EVENT CB

local analog_o_offset_buff = {}
local analog_o_offset_samples = 0

function hid_event(typ, code, val)

  local step_name = setup_steps[curr_setup_step]

  local half_reso = g.dpad_resolution/2

  local event_code_type
  for k, v in pairs(hid_events.types) do
    if tonumber(v) == typ then
      event_code_type = k
      break
    end
  end

  if event_code_type == "EV_ABS" then
    if step_name == 'analog_calibration' then
      table.insert(analog_o_offset_buff, val)
      analog_o_offset_samples = analog_o_offset_samples + 1
      if analog_o_offset_samples > 50 then
        local max_offset = 0
        for _, v in ipairs(analog_o_offset_buff) do
          local offset = math.abs(v - half_reso)
          if offset > max_offset then
            max_offset = offset
          end
        end
        g.dpad_o_margin = max_offset + 2 -- we take some margin
        curr_setup_step = curr_setup_step + 1
      end
    elseif util.string_starts(step_name, 'dpad_') then

      val = val - half_reso
      if val <= half_reso * 2/3 and val >= - half_reso * 2/3 then
        sign = 0
      else
        sign = val < 0 and -1 or 1
      end

      if sign ~= 0 then
        -- TODO: register direction
        curr_setup_step = curr_setup_step + 1
      end
    end
  end

  if event_code_type == "EV_KEY"
    and tab.contains(buttons, step_name)
    and val == 0
  then
    g.button[step_name] = code
    curr_setup_step = curr_setup_step + 1
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
    screen.text(devicepos .. ": ".. truncate_txt(hdevs[devicepos], 19))
  elseif step_name == 'analog_calibration' then
    screen.move(0, 7)
    screen.text("calibrating analog inputs")
  else
    screen.move(0, 7)
    screen.text(step_name)
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

function clear_hid_buffer()
  hid_buffer = {}
  for z=1,hid_buffer_len do
    table.insert(hid_buffer, {})
  end
  buff_start = 1
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
