# gamepad_wiz

WIP norns gamepad config wizard

see https://github.com/monome/norns/pull/1439


TODO:

- [ ] skip analog calibration if no event received after 3 seconds (for digital-only controllers)
- [ ] store calibration & invert axis by `axis_event` and not simply `axis`

indeed, we could very much have a controller that inverts a digital axis (e.g. `ABS_HAT0Y`) but not the analog one (`ABS_Y`)...
