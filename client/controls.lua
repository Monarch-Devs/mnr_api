local disabled = {}         ---@note Disabled controls storage
local mappings = {}         ---@note Indexing table for O(1) access removal
local resource = {}         ---@note Ownership table to ensure owners and avoid race conditions

local counter = 0
local running = false

---@note I hate doing this but is necessary localize the access to the function
local DisableControlAction = DisableControlAction

local function startThread()
    if running then return end
    running = true

    CreateThread(function()
        while counter > 0 do
            for i = 1, counter do
                DisableControlAction(0, disabled[i], true)
            end

            Wait(0)
        end

        running = false
    end)
end

local function disable(control, owner)
    if not resource[owner] then
        resource[owner] = {}
    end

    if resource[owner][control] then
        return false, 'control is already disabled by the resource'
    end

    resource[owner][control] = true

    if not mappings[control] then
        counter += 1
        disabled[counter] = control
        mappings[control] = counter
    end

    startThread()

    return true
end

local function enable(control, owner)
    if not resource[owner] or not resource[owner][control] then
        return false, 'control not found or not owned by the resource'
    end

    resource[owner][control] = nil

    if next(resource[owner]) == nil then
        resource[owner] = nil
    end

    for _, res in pairs(resource) do
        if res[control] then
            return true
        end
    end

    local curr = mappings[control]
    local last = disabled[counter]
    if curr ~= counter then
        disabled[curr] = last
        mappings[last] = curr
    end

    disabled[counter] = nil
    mappings[control] = nil
    counter -= 1

    return true
end

AddEventHandler('onResourceStop', function(name)
    if not resource[name] then return end

    for control in pairs(resource[name]) do
        enable(control, name)
    end
end)

exports('ToggleControl', function(control, toggle)
    local owner = GetInvokingResource()

    if toggle then
        return enable(control, owner)
    else
        return disable(control, owner)
    end
end)