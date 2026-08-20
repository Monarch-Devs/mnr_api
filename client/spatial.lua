---@note Vanilla Map Sizes (No Cayo)| N.E. 4860.00, 8400.00 | S.E. 4860.00, -5100.00 | N.W. -4140.00, 8400.00 | S.W. -4140.00, -5100.00 | 1 chunk 4500x4500

local MIN_X, MAX_X = GetConvarInt('mnr:world:min_x', -4140), GetConvarInt('mnr:world:max_x', 9360)
local MIN_Y, MAX_Y = GetConvarInt('mnr:world:min_y', -9600), GetConvarInt('mnr:world:max_y', 8400)

if MIN_X >= MAX_X then
    error(('mnr:world:min_x (%d) must be less than mnr:world:max_x (%d)'):format(MIN_X, MAX_X), 1)
elseif MIN_Y >= MAX_Y then
    error(('mnr:world:min_y (%d) must be less than mnr:world:max_y (%d)'):format(MIN_Y, MAX_Y), 1)
end

local CELL_SIZE = 250
local TOT_W, TOT_H = math.ceil((MAX_X - MIN_X) / CELL_SIZE), math.ceil((MAX_Y - MIN_Y) / CELL_SIZE)

local entries = {}
local generic, spatial = {}, {}
local activeIds, cachedIds = {}, {}
local nearbyDebug = {}
local counter = -1
local insideByEntry = {}
local pullEntries = {}

local function getCell(grid, x, y)
    local index = y * TOT_W + x
    local cell = grid[index]
    if not cell then
        cell = {}
        grid[index] = cell
    end

    return cell
end

local function translateCoords(x, y)
    local cx = math.floor((x - MIN_X) / CELL_SIZE)
    local cy = math.floor((y - MIN_Y) / CELL_SIZE)

    return math.max(0, math.min(cx, TOT_W - 1)), math.max(0, math.min(cy, TOT_H - 1))
end

local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function getNearbyEntries(grid, minX, minY, maxX, maxY, seen)
    local fx, fy = translateCoords(minX, minY)
    local tx, ty = translateCoords(maxX, maxY)
    for y = fy, ty do
        for x = fx, tx do
            local cell = grid[y * TOT_W + x]
            if cell then
                for entryId in pairs(cell) do
                    seen[entryId] = true
                end
            end
        end
    end

    return seen
end

local function indexEntry(grid, entryId, bounds)
    local fx, fy = translateCoords(bounds.minX, bounds.minY)
    local tx, ty = translateCoords(bounds.maxX, bounds.maxY)
    for y = fy, ty do
        for x = fx, tx do
            getCell(grid, x, y)[entryId] = true
        end
    end
end

local function vxc(coords, x, y, z, cos, sin)
    return vec3(coords.x + x * cos - y * sin, coords.y + x * sin + y * cos, coords.z + z)
end

local function computeBoxVertices(coords, size, rotation)
    local hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
    local c, s = math.cos(rotation), math.sin(rotation)

    return { vxc(coords, -hx, -hy, -hz, c, s), vxc(coords, hx, -hy, -hz, c, s), vxc(coords, hx, hy, -hz, c, s), vxc(coords, -hx, hy, -hz, c, s), vxc(coords, -hx, -hy, hz, c, s), vxc(coords, hx, -hy, hz, c, s), vxc(coords, hx, hy, hz, c, s), vxc(coords, -hx, hy, hz, c, s) }
end

local view = {}

function view.sphere(class)
    DrawMarker(28, class.coords.x, class.coords.y, class.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, class.radius, class.radius, class.radius, 125, 18, 255, 100, false, false, 0, false, nil, nil, false)
end

function view.box(class)
    local v = class.vertices

    DrawPoly(v[1].x, v[1].y, v[1].z, v[4].x, v[4].y, v[4].z, v[3].x, v[3].y, v[3].z, 125, 18, 255, 100)
    DrawPoly(v[3].x, v[3].y, v[3].z, v[4].x, v[4].y, v[4].z, v[1].x, v[1].y, v[1].z, 125, 18, 255, 100)
    DrawPoly(v[1].x, v[1].y, v[1].z, v[3].x, v[3].y, v[3].z, v[2].x, v[2].y, v[2].z, 125, 18, 255, 100)
    DrawPoly(v[2].x, v[2].y, v[2].z, v[3].x, v[3].y, v[3].z, v[1].x, v[1].y, v[1].z, 125, 18, 255, 100)

    DrawPoly(v[5].x, v[5].y, v[5].z, v[6].x, v[6].y, v[6].z, v[7].x, v[7].y, v[7].z, 125, 18, 255, 100)
    DrawPoly(v[7].x, v[7].y, v[7].z, v[6].x, v[6].y, v[6].z, v[5].x, v[5].y, v[5].z, 125, 18, 255, 100)
    DrawPoly(v[5].x, v[5].y, v[5].z, v[7].x, v[7].y, v[7].z, v[8].x, v[8].y, v[8].z, 125, 18, 255, 100)
    DrawPoly(v[8].x, v[8].y, v[8].z, v[7].x, v[7].y, v[7].z, v[5].x, v[5].y, v[5].z, 125, 18, 255, 100)

    DrawPoly(v[1].x, v[1].y, v[1].z, v[2].x, v[2].y, v[2].z, v[6].x, v[6].y, v[6].z, 125, 18, 255, 100)
    DrawPoly(v[6].x, v[6].y, v[6].z, v[2].x, v[2].y, v[2].z, v[1].x, v[1].y, v[1].z, 125, 18, 255, 100)
    DrawPoly(v[1].x, v[1].y, v[1].z, v[6].x, v[6].y, v[6].z, v[5].x, v[5].y, v[5].z, 125, 18, 255, 100)
    DrawPoly(v[5].x, v[5].y, v[5].z, v[6].x, v[6].y, v[6].z, v[1].x, v[1].y, v[1].z, 125, 18, 255, 100)

    DrawPoly(v[2].x, v[2].y, v[2].z, v[3].x, v[3].y, v[3].z, v[7].x, v[7].y, v[7].z, 125, 18, 255, 100)
    DrawPoly(v[7].x, v[7].y, v[7].z, v[3].x, v[3].y, v[3].z, v[2].x, v[2].y, v[2].z, 125, 18, 255, 100)
    DrawPoly(v[2].x, v[2].y, v[2].z, v[7].x, v[7].y, v[7].z, v[6].x, v[6].y, v[6].z, 125, 18, 255, 100)
    DrawPoly(v[6].x, v[6].y, v[6].z, v[7].x, v[7].y, v[7].z, v[2].x, v[2].y, v[2].z, 125, 18, 255, 100)

    DrawPoly(v[3].x, v[3].y, v[3].z, v[4].x, v[4].y, v[4].z, v[8].x, v[8].y, v[8].z, 125, 18, 255, 100)
    DrawPoly(v[8].x, v[8].y, v[8].z, v[4].x, v[4].y, v[4].z, v[3].x, v[3].y, v[3].z, 125, 18, 255, 100)
    DrawPoly(v[3].x, v[3].y, v[3].z, v[8].x, v[8].y, v[8].z, v[7].x, v[7].y, v[7].z, 125, 18, 255, 100)
    DrawPoly(v[7].x, v[7].y, v[7].z, v[8].x, v[8].y, v[8].z, v[3].x, v[3].y, v[3].z, 125, 18, 255, 100)

    DrawPoly(v[4].x, v[4].y, v[4].z, v[1].x, v[1].y, v[1].z, v[5].x, v[5].y, v[5].z, 125, 18, 255, 100)
    DrawPoly(v[5].x, v[5].y, v[5].z, v[1].x, v[1].y, v[1].z, v[4].x, v[4].y, v[4].z, 125, 18, 255, 100)
    DrawPoly(v[4].x, v[4].y, v[4].z, v[5].x, v[5].y, v[5].z, v[8].x, v[8].y, v[8].z, 125, 18, 255, 100)
    DrawPoly(v[8].x, v[8].y, v[8].z, v[5].x, v[5].y, v[5].z, v[4].x, v[4].y, v[4].z, 125, 18, 255, 100)

    DrawLine(v[1].x, v[1].y, v[1].z, v[2].x, v[2].y, v[2].z, 255, 255, 255, 100)
    DrawLine(v[2].x, v[2].y, v[2].z, v[3].x, v[3].y, v[3].z, 255, 255, 255, 100)
    DrawLine(v[3].x, v[3].y, v[3].z, v[4].x, v[4].y, v[4].z, 255, 255, 255, 100)
    DrawLine(v[4].x, v[4].y, v[4].z, v[1].x, v[1].y, v[1].z, 255, 255, 255, 100)
    DrawLine(v[5].x, v[5].y, v[5].z, v[6].x, v[6].y, v[6].z, 255, 255, 255, 100)
    DrawLine(v[6].x, v[6].y, v[6].z, v[7].x, v[7].y, v[7].z, 255, 255, 255, 100)
    DrawLine(v[7].x, v[7].y, v[7].z, v[8].x, v[8].y, v[8].z, 255, 255, 255, 100)
    DrawLine(v[8].x, v[8].y, v[8].z, v[5].x, v[5].y, v[5].z, 255, 255, 255, 100)
    DrawLine(v[1].x, v[1].y, v[1].z, v[5].x, v[5].y, v[5].z, 255, 255, 255, 100)
    DrawLine(v[2].x, v[2].y, v[2].z, v[6].x, v[6].y, v[6].z, 255, 255, 255, 100)
    DrawLine(v[3].x, v[3].y, v[3].z, v[7].x, v[7].y, v[7].z, 255, 255, 255, 100)
    DrawLine(v[4].x, v[4].y, v[4].z, v[8].x, v[8].y, v[8].z, 255, 255, 255, 100)
end

local function newGenericEntry(data)
    return { resource = data.resource, coords = data.coords, bounds = { minX = data.coords.x, minY = data.coords.y, maxX = data.coords.x, maxY = data.coords.y } }
end

local SpatialEntry = {}
SpatialEntry.__index = SpatialEntry

function SpatialEntry.new(data)
    local obj = setmetatable({}, SpatialEntry)
    obj.resource = data.resource
    obj.spatial = true
    obj.shape = data.shape
    obj.event = ('%s:spatial:action'):format(data.resource)
    obj.coords = data.coords
    obj.bounds = data.bounds

    if data.shape == 'sphere' then
        obj.radius = data.radius
        obj.radiusSq = data.radius * data.radius
    else
        obj.size = data.size
        obj.rotation = data.rotation
        obj.invCos = math.cos(-data.rotation)
        obj.invSin = math.sin(-data.rotation)
        obj.halfX = data.size.x * 0.5
        obj.halfY = data.size.y * 0.5
        obj.halfZ = data.size.z * 0.5
    end

    obj.debug = data.debug or false

    if obj.debug and obj.shape == 'box' then
        obj.vertices = computeBoxVertices(data.coords, data.size, data.rotation)
    end

    return obj
end

local check = {}

function check.sphere(class, coords)
    local dx, dy, dz = class.coords.x - coords.x, class.coords.y - coords.y, class.coords.z - coords.z

    return (dx * dx + dy * dy + dz * dz) <= class.radiusSq
end

function check.box(class, coords)
    local dx, dy, dz = coords.x - class.coords.x, coords.y - class.coords.y, coords.z - class.coords.z
    local x = dx * class.invCos - dy * class.invSin
    local y = dx * class.invSin + dy * class.invCos

    return x >= -class.halfX and x <= class.halfX and y >= -class.halfY and y <= class.halfY and dz >= -class.halfZ and dz <= class.halfZ
end

local function pollEntry(id, class, coords)
    local inside = check[class.shape](class, coords)
    if inside == (insideByEntry[id] == true) then
        return
    end

    insideByEntry[id] = inside or nil
    TriggerEvent(class.event, id, inside and 'onEnter' or 'onExit')
end

CreateThread(function()
    while true do
        local coords = GetEntityCoords(mnrEnv.ped)
        clearTable(activeIds)
        getNearbyEntries(spatial, coords.x, coords.y, coords.x, coords.y, activeIds)
        for id in pairs(activeIds) do
            local obj = entries[id]
            if obj then
                pollEntry(id, obj, coords)
            end
        end

        cachedIds, activeIds = activeIds, cachedIds

        Wait(250)
    end
end)

CreateThread(function()
    while true do
        local coords = GetEntityCoords(mnrEnv.ped)
        clearTable(nearbyDebug)
        getNearbyEntries(spatial, coords.x - 100.0, coords.y - 100.0, coords.x + 100.0, coords.y + 100.0, nearbyDebug)

        local found = false
        for id in pairs(nearbyDebug) do
            local entry = entries[id]
            if entry and entry.debug then
                view[entry.shape](entry)
                found = true
            end
        end

        Wait(found and 0 or 1000)
    end
end)

local function getShapeBounds(shape, coords, radius, size)
    if shape == 'sphere' then
        return { minX = coords.x - radius, minY = coords.y - radius, maxX = coords.x + radius, maxY = coords.y + radius }
    elseif shape == 'box' then
        local hd = math.sqrt(size.x * size.x + size.y * size.y) * 0.5

        return { minX = coords.x - hd, minY = coords.y - hd, maxX = coords.x + hd, maxY = coords.y + hd }
    end
end

---@param entryId number
local function deleteEntry(entryId)
    local obj = entries[entryId]
    local grid = obj.spatial and spatial or generic

    local fx, fy = translateCoords(obj.bounds.minX, obj.bounds.minY)
    local tx, ty = translateCoords(obj.bounds.maxX, obj.bounds.maxY)
    for y = fy, ty do
        for x = fx, tx do
            local index = y * TOT_W + x
            local cell = grid[index]
            if cell then
                cell[entryId] = nil
                if not next(cell) then
                    grid[index] = nil
                end
            end
        end
    end

    insideByEntry[entryId] = nil

    entries[entryId] = nil
end

---@param data table
---@return number? entryId, string? error
local function addEntry(data)
    local resource = GetInvokingResource()

    local normalized, err = mnr.typecheck.schema(data, { coords = { expected = 'vector3', required = true } }, { resource = resource })
    if not normalized then
        return nil, err
    end

    if normalized.coords.x < MIN_X or normalized.coords.x > MAX_X or normalized.coords.y < MIN_Y or normalized.coords.y > MAX_Y then
        return nil, 'entry is outside world bounds'
    end

    counter += 2
    local entryId = counter

    entries[entryId] = newGenericEntry(normalized)
    indexEntry(generic, entryId, { minX = normalized.coords.x, minY = normalized.coords.y, maxX = normalized.coords.x, maxY = normalized.coords.y })

    return entryId
end

local function addSpatial(data)
    local resource = GetInvokingResource()

    local normalized, err = nil, nil
    if data.shape == 'sphere' then
        normalized, err = mnr.typecheck.schema(data, { coords = { expected = 'vector3', required = true }, radius = { expected = 'number', defaults = 1.0 }, debug = { expected = 'boolean' } }, { shape = 'sphere' })
    elseif data.shape == 'box' then
        normalized, err = mnr.typecheck.schema(data, { coords = { expected = 'vector3', required = true }, size = { expected = 'vector3', defaults = vec3(1.0, 1.0, 1.0) }, rotation = { expected = 'number', defaults = 0.0 }, debug = { expected = 'boolean' } }, { shape = 'box' })

        if normalized then
            normalized.rotation = math.rad(normalized.rotation)
        end
    else
        normalized, err = nil, ('unknown entry shape "%s"'):format(tostring(data.shape))
    end

    if not normalized then
        return nil, err
    end

    local bounds = getShapeBounds(normalized.shape, normalized.coords, normalized.radius, normalized.size)
    if bounds.maxX < MIN_X or bounds.minX > MAX_X or bounds.maxY < MIN_Y or bounds.minY > MAX_Y then
        return nil, 'entry is outside world bounds'
    end

    counter += 2
    local entryId = counter

    normalized.resource = resource
    normalized.bounds = bounds

    entries[entryId] = SpatialEntry.new(normalized)
    indexEntry(spatial, entryId, bounds)

    return entryId
end

---@param entryId number
---@return boolean success, string? error
local function removeEntry(entryId)
    local resource = GetInvokingResource()

    if type(entryId) ~= 'number' then
        return false, ('entry ID must be a number (received %s)'):format(type(entryId))
    end

    if not entries[entryId] then
        return false, ('entry #%d does not exist'):format(entryId)
    end

    if entries[entryId].resource ~= resource then
        return false, ('resource "%s" cannot remove entry %d owned by "%s"'):format(resource, entryId, entries[entryId].resource)
    end

    deleteEntry(entryId)

    return true
end

---@param coords vector3
---@return table? result, string? error
local function getEntry(coords)
    local resource = GetInvokingResource()

    if type(coords) ~= 'vector3' then
        return nil, ('coords must be a vector3 (received %s)'):format(type(coords))
    end

    clearTable(pullEntries)

    getNearbyEntries(generic, coords.x - CELL_SIZE, coords.y - CELL_SIZE, coords.x + CELL_SIZE, coords.y + CELL_SIZE, pullEntries)
    local nearest
    local nearestDistance = math.huge
    for id in pairs(pullEntries) do
        local entry = entries[id]
        if entry and entry.resource == resource then
            local dx, dy, dz = entry.coords.x - coords.x, entry.coords.y - coords.y, entry.coords.z - coords.z
            local distance = dx * dx + dy * dy + dz * dz
            if distance < nearestDistance then
                nearest = entry
                nearestDistance = distance
            end
        end
    end

    return nearest
end

---@param coords vector3
---@param radius number
---@return table? result, string? error
local function getEntries(coords, radius)
    local resource = GetInvokingResource()

    if type(coords) ~= 'vector3' then
        return nil, ('coords must be a vector3 (received %s)'):format(type(coords))
    end

    if type(radius) ~= 'number' then
        return nil, ('radius must be a number (received %s)'):format(type(radius))
    end

    clearTable(pullEntries)

    getNearbyEntries(generic, coords.x - radius, coords.y - radius, coords.x + radius, coords.y + radius, pullEntries)
    local result = {}
    for id in pairs(pullEntries) do
        if entries[id] and entries[id].resource == resource then
            result[#result + 1] = entries[id]
        end
    end

    return result
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end

    for entryId, class in pairs(entries) do
        if class.resource == resourceName then
            deleteEntry(entryId)
        end
    end
end)

exports('AddEntry', addEntry)
exports('AddSpatial', addSpatial)
exports('RemoveEntry', removeEntry)
exports('GetEntry', getEntry)
exports('GetEntries', getEntries)