# gamepad_wiz

WIP norns gamepad config wizard

see https://github.com/monome/norns/pull/1439 & https://github.com/monome/norns/pull/1624


## about norns gamepad support

4 callbacks are registerable.

#### `gamepad.button(button_name, state)`

gets triggered when a button is pressed or released.

please note that dpad arrows don't count as buttons and one should use `gamepad.dpad` for this use-case.

`button_name` can take the value: `A`, `B`, `X`, `Y`, `L1`, `L2`, `R1`, `R2`, `START`, `SELECT`.

`state` is either `true` (pressed) or false (released).


#### `gamepad.dpad(axis, sign)`

gets triggered when a dpad arrow is pressed or released.

`axis` can take the value `X` or `Y`

sign is either `-1` or `1` (for each side of an axis) or `0` (released).


#### `gamepad.axis(sensor_axis, sign)`

like gets `gamepad.dpad` but gets triggered for sensor axis change.

`sensor_axis` can take the value: `dpady`, `dpadx`, `lefty`, `leftx`, `righty`, `rightx`, `triggerleft`, `triggerright` (same naming convention as SDL).

sign is either `-1` or `1` for each half-travel or `0` (centered).

please note that for `triggerleft` and `triggerright`, the resting (released) position is usually `-1` instead of `0`.


#### `gamepad.analog(sensor_axis, val, half_reso)`

gets triggered on change of value of an analog sensor (analog direction pad, joystick, trigger buttons).

`sensor_axis` can take the value: `lefty`, `leftx`, `righty`, `rightx`, `triggerleft`, `triggerright` (same namiong convention as SDL).

it sends the raw sensor value (`val`) noramized around 0 as well as `half_reso`, the min/max value atainable on each side of the travel.

so `val` can only go between `-half_reso` and `half_reso`.


## examples

#### A button is pressed

- `gamepad.state.A` gets set to `true`
- `gamepad.button('A', true)`


#### digital dpad down is pressed

- `gamepad.state.DPDOWN` gets set to `true`
- `gamepad.axis('dpady', -1)`
- `gamepad.dpad('Y', -1)`


#### analog dpad down is pressed

- `gamepad.analog('dpady', -100, 127)` (example values)
- `gamepad.state.DPDOWN` gets set to `true`
- `gamepad.axis('dpady', -1)`
- `gamepad.dpad('Y', -1)`


#### analog left stick down is pressed

- `gamepad.analog('lefty', -100, 127)` (example values)
- `gamepad.state.LDOWN` gets set to `true`
- `gamepad.axis('lefty', -1)`


#### analog left shoulder button is pressed

- `gamepad.analog('triggerleft', 230, 255)` (example values)
- `gamepad.state.TLEFT` gets set to `true`
- `gamepad.axis('triggerleft', 1)`
- `gamepad.trigger_button('L2', true)`


## implementation details

#### why not use standard HID event codes in callbacks?

controllers are weird and don't follow a strict convention.

for example `ABS_RX` is sometimes associated w/ the left joystick instead of the right one.

likewise, dpads are sometimes digital (`ABS_HAT0X` / `ABS_HAT0Y`) and sometimes analog (`ABS_X` / `ABS_Y`).

using SDL `sensor_axis` codes (`dpadx`, `leftx`...) w/ controller mapping profiles makes for a more predicable experience.
