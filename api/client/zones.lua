local _zones = {}
local _inside = {}

---@param shape 'sphere' | 'box'
---@param data table
---@return table? runtime, table? spatial, string? err
local function validate(shape, data)
    local runtime, err = mnr.typecheck.schema(data, { metadata = { expected = 'table' }, onEnter = { expected = 'function' }, onExit = { expected = 'function' }, inside = { expected = 'function' } })
    if not runtime then
        return nil, nil, err
    end

    return runtime, { shape = shape, coords = data.coords, radius = data.radius, size = data.size, rotation = data.rotation, debug = data.debug }
end

local function startInside(zone)
    if _inside[zone.id] or not zone.inside then return end

    _inside[zone.id] = true

    CreateThread(function()
        while _inside[zone.id] do
            zone.inside(zone)

            Wait(0)
        end
    end)
end

local function stopInside(zone)
    _inside[zone.id] = nil
end

local Zone = {}
Zone.__index = Zone

function Zone:new(shape, data)
    local runtime, spatial, type_err = validate(shape, data)
    if not runtime or not spatial then
        error(type_err, 3)
    end

    local entryId, add_err = exports.mnr_api:AddSpatial(spatial)
    if not entryId then
        error(add_err, 3)
    end

    runtime.id = entryId

    local zone = setmetatable(runtime, self)

    _zones[entryId] = zone

    return zone
end

function Zone:remove()
    local success, err = exports.mnr_api:RemoveEntry(self.id)
    if not success then
        error(err, 2)
    end

    stopInside(self)
    _zones[self.id] = nil

    return success
end

AddEventHandler(('%s:spatial:action'):format(mnrEnv.resource), function(id, action)
    if GetInvokingResource() ~= 'mnr_api' then
        return
    end

    if action ~= 'onEnter' and action ~= 'onExit' then
        return
    end

    local zone = _zones[id]
    if not zone then
        return
    end

    if action == 'onEnter' then
        if zone.onEnter then
            zone.onEnter(zone)
        end

        startInside(zone)

    elseif action == 'onExit' then
        stopInside(zone)

        if zone.onExit then
            zone.onExit(zone)
        end
    end
end)

local zones = {}

function zones.sphere(data)
    return Zone:new('sphere', data)
end

function zones.box(data)
    return Zone:new('box', data)
end

return zones