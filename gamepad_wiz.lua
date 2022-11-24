-- gamepad_wiz.
--
-- @eigen

-- TODO: when doing a prev_step(), should go back 2 step for whole axis!!!

local inspect = include('lib/inspect')

if gamepad == nil then
  gamepad = include('lib/gamepad')
end

local hid_device_param = "hid_device"
local hid_utils = include('lib/hid_utils')

local string_utils = include('lib/string_utils')
local math_utils = include('lib/math_utils')
local tab_utils = include('lib/tab_utils')


-- ------------------------------------------------------------------------
-- STEPS - CONF

local setup_steps = {
  'choose_device',
  'analog_calibration',

  'dpady',
  'dpadx',
  'lefty',
  'leftx',
  'righty',
  'rightx',
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

local function step_2_axis(step_name)
  if step_name == 'dpady' or step_name == 'lefty' then
    return 'Y'
  elseif step_name == 'dpadx' or step_name == 'lefty' then
    return 'X'
  elseif step_name == 'righty' then
    return 'RY' -- NB: sometimes RZ
  elseif step_name == 'rightx' then
    return 'RX' -- NB: sometimes Z
  end
end

local function step_to_sensor_axis(step_name)
  return step_name
  -- if tab.contains({'dpad_down', 'dpad_up'}, step_name) then
  --   return 'dpady'
  -- elseif tab.contains({'dpad_left', 'dpad_right'}, step_name) then
  --   return 'dpadx'
  -- elseif tab.contains({'lstick_down', 'lstick_up'}, step_name) then
  --   return 'lefty'
  -- elseif tab.contains({'lstick_left', 'lstick_right'}, step_name) then
  --   return 'leftx'
  -- elseif tab.contains({'rstick_down', 'rstick_up'}, step_name) then
  --   return 'righty'
  -- elseif tab.contains({'rstick_left', 'rstick_right'}, step_name) then
  --   return 'rightx'
  -- end
end

-- ------------------------------------------------------------------------
-- STATE

local curr_setup_step = 1

local msg = {}

local seconds_to_wait_for_analog_input = 2

g = {
  hid_name = nil,
  alias = nil,

  button = {},

  dpad_is_analog = false,

  axis_mapping = {
  },

  axis_invert = {
  },

  analog_axis_o_margin = {},
  analog_axis_o = {},
  analog_axis_resolution = {},
}


-- ------------------------------------------------------------------------
-- TMP STATE - ANALOG SAMPLING

local ANALOG_CALIBRATION_SAMPLES_PER_AXIS = 50

local analog_v_buff = {}
local analog_v_buff_nb_axis = 0
local analog_v_nb_samples = 0

local function reset_analog_input_samples()
  analog_v_buff = {}
  analog_v_nb_samples = 0
  analog_v_buff_nb_axis = 0
end

local function sample_axis_event(code, val)
  local axis_keycode = gamepad.axis_code_2_keycode(code)
  local is_analog = gamepad.is_axis_keycode_analog(axis_keycode)

  if not is_analog then
    return
  end

  if analog_v_buff[axis_keycode] == nil then
    analog_v_buff[axis_keycode] = {}
    analog_v_buff_nb_axis = analog_v_buff_nb_axis + 1
  end

  table.insert(analog_v_buff[axis_keycode], val)
  analog_v_nb_samples = analog_v_nb_samples + 1
end


-- ------------------------------------------------------------------------
-- TMP STATE - HALF ANALOG AXIS

local prev_half_axis = nil

local function register_half_axis(axis_keycode, min, max, direction)

  -- NB: this is no more necessary
  local vals_text = ""
  if direction > 1 then
    vals_text = min.." -> "..max .. "(fw)"
  else
    vals_text = max.." -> "..min .. "(bw)"
  end
  print("axis is "..axis_keycode..", captured values: "..vals_text)

  prev_half_axis = {
    min = min,
    max = max,
    direction = direction,
    axis_keycode = axis_keycode,
  }
end

local function current_half_axis_name(step_name)
  if step_name == 'dpady' then
    if prev_half_axis == nil then
      return "dpad down"
    else
      return "dpad up"
    end
  elseif step_name == 'dpadx' then
    if prev_half_axis == nil then
      return "dpad left"
    else
      return "dpad right"
    end
  elseif step_name == 'lefty' then
    if prev_half_axis == nil then
      return "left stick down"
    else
      return "left stick up"
    end
  elseif step_name == 'leftx' then
    if prev_half_axis == nil then
      return "left stick left"
    else
      return "left stick right"
    end
  elseif step_name == 'righty' then
    if prev_half_axis == nil then
      return "right stick down"
    else
      return "right stick up"
    end
  elseif step_name == 'rightx' then
    if prev_half_axis == nil then
      return "right stick left"
    else
      return "right stick right"
    end
  end
end


-- ------------------------------------------------------------------------
-- SAVING

local function save_gamepad (g, filename)
  local gamepad_data_dir = _path.data .. "gamepads/"
  util.make_dir(gamepad_data_dir)
  tab_utils.save(g, gamepad_data_dir .. filename .. ".lua")
  -- tab_utils.save(g, "/tmp/" .. filename .. ".lua")
end

-- local function save_n_register_gamepad (g)
--   local dev_filename = string_utils.trim(g.alias):gsub('%W','_')
--   save_gamepad(g, dev_filename)
--   local file, err = io.open("/home/we/norns/lua/core/gamepad_model/index.lua", "wb")
--   -- local file, err = io.open("/tmp/index.lua", "wb")
--   if err then return err end
--   file:write("\n")
--   file:write("local models = {}\n")
--   file:write("\n")
--   file:write("models['" .. g.hid_name .. "']" .. "= require 'gamepad_model/" .. dev_filename .. "'\n")
--   file:write("\n")
--   file:write("return models\n")
--   file:close()
-- end


-- ------------------------------------------------------------------------
-- STATE <-> STEPS BINDINGS

local after_step_change = function() end

local function redo_step()
  after_step_change()
end

local function next_step()
  curr_setup_step = curr_setup_step + 1
  after_step_change()
end

local function prev_step()
  curr_setup_step = curr_setup_step - 1
  after_step_change()
end

local function is_axis_step(step_name)
  return util.string_starts(step_name, 'dpad')
    or util.string_starts(step_name, 'left')
    or util.string_starts(step_name, 'right')
end

local function is_at_axis_step()
  return is_axis_step(setup_steps[curr_setup_step])
end

local function is_button_step(step_name)
  return tab.contains(buttons, step_name)
end

local function is_at_button_step()
  return is_button_step(setup_steps[curr_setup_step])
end

after_step_change = function()
  local step_name = setup_steps[curr_setup_step]

  print(inspect(g))
  print("-----------------------------------")
  print("  => "..step_name)

  if step_name == 'analog_calibration' then
    reset_analog_input_samples()
    g.analog_axis_o_margin = {}
    clock.run(
      function()
        clock.sleep(seconds_to_wait_for_analog_input)
        if analog_v_nb_samples == 0 then
          print("no analog input or they are not noisy")
          next_step()
        end
    end)
  elseif is_at_axis_step() then
    reset_analog_input_samples()
    prev_half_axis = nil
    -- local tested_axis = step_2_axis(step_name)
    -- if tested_axis ~= nil then
    --   print("now at "..step_name.." -> testing axis: ".. tested_axis)
    -- end
  elseif tab.contains(buttons, step_name) then
    g.button[step_name] = nil
  elseif step_name == 'confirm' then
    local dev_name = hid_utils.name_current()
    g.hid_name = dev_name
    g.alias = string_utils.trim(dev_name) -- FIXME: promt user?
    print(inspect(g))
  elseif step_name == 'end' then
    local dev_name = hid_utils.name_current()
    g.hid_name = dev_name
    g.alias = string_utils.trim(dev_name) -- FIXME: promt user?
    local dev_filename = string_utils.trim(g.alias):gsub('%W','_')
    save_gamepad(g, dev_filename)
  end
end


-- ------------------------------------------------------------------------
-- SCRIPT LIFECYCLE

local fps = 15
local redraw_clock = nil

function init()
  hid_utils.connect_current(hid_event)
  hid_utils.lookup()
  hid_utils.print()

  params:add{type = "option", id = hid_device_param, name = "HID-device", options = hid_utils.param_options(), default = 1,
             action = function(devicepos)
               hid_utils.param_action(hid_device_param, devicepos, hid_event)
  end}

  screen.aa(1)
  screen.line_width(1)

  redraw_clock = clock.run(
    function()
      local step_s = 1 / fps
      while true do
        clock.sleep(step_s)
        redraw()
      end
  end)
end

function cleanup()
  clock.cancel(redraw_clock)
end


-- ------------------------------------------------------------------------
-- I/O

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
function enc(n, d)
  local step_name = setup_steps[curr_setup_step]
  if step_name ~= 'choose_device' then
    return
  end

  if n == 1 then
    hid_utils.enc(hid_device_param, delta)
  end
  -- redraw()
end


-- ------------------------------------------------------------------------
-- HID EVENT CB

local function hid_event_analog_calibration(code, val)
  sample_axis_event(code, val)

  -- REVIEW: maybe ensure that each axis got all of its events
  if (analog_v_nb_samples / analog_v_buff_nb_axis) > ANALOG_CALIBRATION_SAMPLES_PER_AXIS then
    local max_offsets = {}
    for axis_keycode, samples in pairs(analog_v_buff) do
      max_offsets[axis_keycode] = math_utils.max_offset(samples)
    end
    g.analog_axis_o_margin[axis_keycode] = max_offsets
    next_step()
  end
end

local prev_axis_log = nil


local function hid_event_axis(code, val)
  local step_name = setup_steps[curr_setup_step]

  local axis_keycode = gamepad.axis_code_2_keycode(code)
  local is_analog = gamepad.is_axis_keycode_analog(axis_keycode)

  -- ignore events caused by noisy sensors
  if gamepad.is_analog_origin(g, axis_keycode, val) then
    return
  end

  -- ignore events for axis other than current one (if other half done)
  if prev_half_axis ~= nil and axis_keycode ~= prev_half_axis.axis_keycode then
    return
  end

  -- ignore events for axis already processed
  if tab.contains(tab_utils.keys(g.axis_mapping), axis_keycode) then
    return
  end


  local sensor_axis = step_to_sensor_axis(step_name)

  if not is_analog and val ~= 0 then
    -- TODO: remove this 1:1 limitation, might not always work
    -- local tested_axis = step_2_axis(step_name)
    -- if axis ~= tested_axis then
    --   local log = "pressed "..axis.." while expected "..tested_axis
    --   if log ~= prev_axis_log then
    --     print(log)
    --     prev_axis_log = log
    --   end
    --   return
    -- end

    print("                             NOT ANALOG!!!")

    g.axis_mapping[axis_keycode] = sensor_axis

    local sign = val
    if sign ~= 0 then
      sign = val < 0 and -1 or 1
    end

    -- REVIEW: replace those w/ `sensor_axis` as the key?
    if sign ~= 0 then
      if sign < 0 then
        g.axis_invert[axis_keycode] = true
      else
        g.axis_invert[axis_keycode] = false
      end
      next_step()
      return
    end
  end

  sample_axis_event(code, val)

  if analog_v_nb_samples  > ANALOG_CALIBRATION_SAMPLES_PER_AXIS then
    local max_nb_events = 0
    local tested_axis = 0
    for axis_keycode, samples in pairs(analog_v_buff) do
      local nb_events = tab.count(samples)
      if nb_events > max_nb_events then
        max_nb_events = nb_events
        tested_axis = axis_keycode
      end
    end

    local min = math_utils.min(analog_v_buff[tested_axis])
    local max = math_utils.max(analog_v_buff[tested_axis])

    local count_dir_pos = 0
    local count_dir_neg = 0
    for i=2,6 do
      if analog_v_buff[tested_axis][i+1] > analog_v_buff[tested_axis][i] then
        count_dir_pos = count_dir_pos + 1
      elseif analog_v_buff[tested_axis][i+1] < analog_v_buff[tested_axis][i] then
        count_dir_neg = count_dir_neg + 1
      end
    end

    -- NB: this is no more necessary
    local direction = 1
    if count_dir_pos > count_dir_neg then
      direction = 1
      print("postive direction: "..min.." -> "..max)
    elseif count_dir_pos < count_dir_neg then
      direction = -1
      print("negative direction: "..max.." -> "..min)
    else
      print("couldn't determine direction (draw between "..count_dir_pos.." vs "..count_dir_neg.."), should retest of only consider first half of samples")
      -- redo_step()
      return
    end

    if prev_half_axis == nil then
      register_half_axis(tested_axis, min, max, direction)
      reset_analog_input_samples()
    else

      if is_analog and util.string_starts(step_name, 'dpad') then
        g.dpad_is_analog = true
      end

      g.axis_mapping[tested_axis] = sensor_axis

      local min = math.min(prev_half_axis.min, min)
      local max = math.max(prev_half_axis.max, max)

      if min < -32000 and max > 32000 then
        min = -32768
        max = 32767
        local resolution = max - min
        g.analog_axis_resolution[tested_axis] = resolution
        g.analog_axis_o[tested_axis] = 0
      elseif min >= 0 and max <= 256 then
        min = 0
        max = 256
        local resolution = max - min
        g.analog_axis_resolution[tested_axis] = resolution
        g.analog_axis_o[tested_axis] = 127
      else
        local resolution = max - min
        g.analog_axis_resolution[tested_axis] = resolution
        g.analog_axis_o[tested_axis] = math.floor(max - (resolution/2))
      end


      if prev_half_axis.min < min then
        g.axis_invert[tested_axis] = true
      else
        g.axis_invert[tested_axis] = false
      end
      next_step()
      return
    end
  end

  -- older code

  -- local sign = val
  -- local axis_keycode = gamepad.axis_code_2_keycode(code)
  -- local axis = gamepad.direction_event_code_type_to_axis(axis_keycode)
  -- local is_analog = gamepad.is_axis_keycode_analog(axis_keycode)

  -- -- TODO: remove this 1:1 limitation, not working in practice
  -- if axis ~= tested_axis then
  --   local log = "pressed "..axis.." while expected "..tested_axis
  --   if log ~= prev_axis_log then
  --     print(log)
  --     prev_axis_log = log
  --   end
  --   return
  -- end


  -- NB: bellow is the old code that relied

  -- TODO: stop relying on this!!!
  -- local half_reso = g.analog_axis_resolution/2

  -- if is_analog then
  --   val = val - half_reso
  --   if val <= half_reso * 2/3 and val >= - half_reso * 2/3 then
  --     sign = 0
  --   else
  --     sign = val < 0 and -1 or 1
  --   end
  -- else -- digital
  --   if sign ~= 0 then
  --     sign = val < 0 and -1 or 1
  --   end
  -- end

  -- if is_analog and util.string_starts(step_name, 'dpad_') then
  --   g.dpad_is_analog = true
  -- end

  -- if sign ~= 0 then
  --   if sign < 0 then
  --     g.axis_invert[tested_axis] = true
  --   else
  --     g.axis_invert[tested_axis] = false
  --   end
  --   next_step()
  -- end

end

function hid_event_button(code, val)
  local step_name = setup_steps[curr_setup_step]
  if val == 0 then
    g.button[step_name] = code
    next_step()
  end
end

function hid_event(typ, code, val)
  local step_name = setup_steps[curr_setup_step]

  local event_code_type = hid_utils.event_type_code(typ)

  if event_code_type == "EV_ABS" then
    if step_name == 'analog_calibration' then
      hid_event_analog_calibration(code, val)
    elseif is_at_axis_step() then
      hid_event_axis(code, val)
    end
  end
  -- TODO: buttons also can be analog!!!
  if event_code_type == "EV_KEY"
    and is_at_button_step()
  then
    hid_event_button(code, val)
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
    screen.text(hid_utils.pos_current() .. ": ".. string_utils.truncate(hid_utils.name_current(), 19))
    screen.move(0, 64-10)
    screen.text("E1: select, K3: next")
  elseif step_name == 'analog_calibration' then
    screen.move(0, 7)
    screen.text("calibrating analog inputs")
    screen.move(0, 17)
    local total = "???"
    if analog_v_buff_nb_axis > 0 then
      total = (ANALOG_CALIBRATION_SAMPLES_PER_AXIS * analog_v_buff_nb_axis)
    end
    screen.text("(" .. analog_v_nb_samples .. "/" .. total .. ")")
    screen.move(0, 64-10)
    screen.text("K2: prev")
  elseif is_at_axis_step()
    or is_at_button_step() then
    if is_at_axis_step() then
      screen.move(0, 17)
      screen.text("(" .. analog_v_nb_samples .. "/" .. ANALOG_CALIBRATION_SAMPLES_PER_AXIS.. ")")
    end
    screen.move(0, 7)
    if is_at_axis_step() then
      screen.text("press "..current_half_axis_name(step_name))
    else
      screen.text("press "..step_name)
    end
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
