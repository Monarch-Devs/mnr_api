local keymappings = {}

-- Guard function to avoid checks on not existant tables
---@param id string ID of the device where the keymapping is registered [https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/]
---@return table
local function getDevice(id)
    keymappings[id] = keymappings[id] or {}

    return keymappings[id]
end

-- Registration system for controls to avoid conflicts
---@param data MnrKeymappingOptions
---@return boolean success, string? error
local function registerControl(data)
    local resource = GetInvokingResource()

    local used = getDevice(data.default.device)[data.default.control]
    if used then
        return false, ('attempted to register a default keymapping [%s] [%s] already used by (%s)'):format(data.default.device, data.default.control, used)
    end

    if data.secondary then
        local used2nd = getDevice(data.secondary.device)[data.secondary.control]
        if used2nd then
            return false, ('attempted to register a secondary keymapping [%s] [%s] already used by (%s)'):format(data.secondary.device, data.secondary.control, used2nd)
        end
    end

    keymappings[data.default.device][data.default.control] = resource

    if data.secondary then
        keymappings[data.secondary.device][data.secondary.control] = resource
    end

    return true
end

exports('RegisterControl', registerControl)