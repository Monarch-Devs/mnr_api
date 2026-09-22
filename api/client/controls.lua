---@class MnrControlsAPI
local controls = {}

function controls.enable(control)
    local success, err = exports.mnr_api:ToggleControl(control, true)
    if not success then
        error(err, 2)
    end
end

function controls.disable(control)
    local success, err = exports.mnr_api:ToggleControl(control, false)
    if not success then
        error(err, 2)
    end
end

return controls