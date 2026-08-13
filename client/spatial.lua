---@note Vanilla Map Sizes (No Cayo)| N.E. 4860.00, 8400.00 | S.E. 4860.00, -5100.00 | N.W. -4140.00, 8400.00 | S.W. -4140.00, -5100.00 | 1 chunk 4500x4500

local MIN_X, MAX_X = GetConvarInt('mnr:world:min_x', -4140), GetConvarInt('mnr:world:max_x', 9360)
local MIN_Y, MAX_Y = GetConvarInt('mnr:world:min_y', -9600), GetConvarInt('mnr:world:max_y', 8400)

if MIN_X >= MAX_X then
    error(('mnr:world:min_x (%d) must be less than mnr:world:max_x (%d)'):format(MIN_X, MAX_X), 1)
elseif MIN_Y >= MAX_Y then
    error(('mnr:world:min_y (%d) must be less than mnr:world:max_y (%d)'):format(MIN_Y, MAX_Y), 1)
end

local CELL_SIZE = 250
local GRID_WIDTH = math.ceil((MAX_X - MIN_X) / CELL_SIZE)
local GRID_HEIGHT = math.ceil((MAX_Y - MIN_Y) / CELL_SIZE)

local generic = {}
local spatial = {}
local entries = {}
local counter = -1
local insideByEntry = {}
local nearbyIds = {}
local prevNearbyIds = {}

local function getIndex(x, y)
    return y * GRID_WIDTH + x
end

local function getCell(grid, x, y)
    local index = getIndex(x, y)

    local cell = grid[index]
    if not cell then
        cell = {}
        grid[index] = cell
    end

    return cell
end

local function worldToCell(x, y)
    local cx = math.floor((x - MIN_X) / CELL_SIZE)
    local cy = math.floor((y - MIN_Y) / CELL_SIZE)

    return math.max(0, math.min(cx, GRID_WIDTH - 1)), math.max(0, math.min(cy, GRID_HEIGHT - 1))
end

local function getCellRange(minX, minY, maxX, maxY)
    local fx, fy = worldToCell(minX, minY)
    local tx, ty = worldToCell(maxX, maxY)

    return fx, fy, tx, ty
end

local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function getEntriesInRange(grid, minX, minY, maxX, maxY, seen)
    seen = seen or {}

    local fx, fy, tx, ty = getCellRange(minX, minY, maxX, maxY)
    for cellY = fy, ty do
        for cellX = fx, tx do
            local index = getIndex(cellX, cellY)
            local cell = grid[index]
            if cell then
                for entryId in pairs(cell) do
                    seen[entryId] = true
                end
            end
        end
    end

    return seen
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
    return { resource = data.resource, coords = data.coords }
end

local SpatialEntry = {}
SpatialEntry.__index = SpatialEntry

function SpatialEntry.new(data)
    local obj = setmetatable({}, SpatialEntry)

    obj.resource = data.resource
    obj.spatial = data.spatial
    obj.shape = data.shape
    obj.event = ('%s:spatial:action'):format(data.resource)

    obj.coords = data.coords
    obj.aabb = data.aabb

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
    obj.drawing = false

    if obj.debug and obj.shape == 'box' then
        obj.vertices = computeBoxVertices(data.coords, data.size, data.rotation)
    end

    return obj
end

function SpatialEntry:activateDebug()
    if not self.debug or self.drawing then return end

    self.drawing = true

    CreateThread(function()
        while self.drawing do
            view[self.shape](self)
            Wait(0)
        end
    end)
end

function SpatialEntry:deactivateDebug()
    self.drawing = false
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

        clearTable(nearbyIds)
        getEntriesInRange(spatial, coords.x - CELL_SIZE, coords.y - CELL_SIZE, coords.x + CELL_SIZE, coords.y + CELL_SIZE, nearbyIds)

        for id in pairs(nearbyIds) do
            local obj = entries[id]
            if obj then
                pollEntry(id, obj, coords)

                if not prevNearbyIds[id] then
                    obj:activateDebug()
                end
            end
        end

        for id in pairs(prevNearbyIds) do
            if not nearbyIds[id] then
                local obj = entries[id]
                if obj then
                    obj:deactivateDebug()
                end
            end
        end

        prevNearbyIds, nearbyIds = nearbyIds, prevNearbyIds

        Wait(300)
    end
end)

local function getShapeBounds(shape, coords, radius, size)
    if shape == 'sphere' then
        return coords.x - radius, coords.y - radius, coords.z - radius, coords.x + radius, coords.y + radius, coords.z + radius
    end

    local hd = math.sqrt(size.x * size.x + size.y * size.y) * 0.5
    local z = size.z * 0.5

    return coords.x - hd, coords.y - hd, coords.z - z, coords.x + hd, coords.y + hd, coords.z + z
end

---@param entryId number
local function deleteEntry(entryId)
    local obj = entries[entryId]
    local grid, fromX, fromY, toX, toY

    if obj.spatial then
        grid = spatial
        fromX, fromY, toX, toY = getCellRange(obj.aabb.minX, obj.aabb.minY, obj.aabb.maxX, obj.aabb.maxY)
    else
        grid = generic
        fromX, fromY = worldToCell(obj.coords.x, obj.coords.y)
        toX, toY = fromX, fromY
    end

    for cellY = fromY, toY do
        for cellX = fromX, toX do
            local index = getIndex(cellX, cellY)
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

    if obj.spatial then
        entries[entryId]:deactivateDebug()
    end

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

    local x, y = worldToCell(normalized.coords.x, normalized.coords.y)
    getCell(generic, x, y)[entryId] = true

    return entryId
end

local function addSpatial(data)
    local resource = GetInvokingResource()

    local normalized, err = nil, nil
    if data.shape == 'sphere' then
        normalized, err = mnr.typecheck.schema(data, { coords = { expected = 'vector3', required = true }, radius = { expected = 'number', defaults = 1.0 }, debug = { expected = 'boolean' } }, { shape = 'sphere' })
    elseif data.shape == 'box' then
        normalized, err = mnr.typecheck.schema(data, { coords = { expected = 'vector3', required = true }, size = { expected = 'vector3', defaults = vec3(1.0, 1.0, 1.0) }, rotation = { expected = 'number', defaults = 0.0 }, debug = { expected = 'boolean' } }, { shape = 'box' })
    else
        normalized, err = nil, ('unknown entry shape "%s"'):format(tostring(data.shape))
    end

    if not normalized then
        return nil, err
    end

    local minX, minY, minZ, maxX, maxY, maxZ = getShapeBounds(normalized.shape, normalized.coords, normalized.radius, normalized.size)
    if maxX < MIN_X or minX > MAX_X or maxY < MIN_Y or minY > MAX_Y then
        return nil, 'entry is outside world bounds'
    end

    counter += 2
    local entryId = counter

    normalized.resource = resource
    normalized.spatial = true
    normalized.aabb = { minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ }

    entries[entryId] = SpatialEntry.new(normalized)

    local fx, fy, tx, ty = getCellRange(minX, minY, maxX, maxY)
    for y = fy, ty do
        for x = fx, tx do
            getCell(spatial, x, y)[entryId] = true
        end
    end

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
---@param mode 'single' | 'radius'
---@param radius number
---@return table? result, string? error
local function getEntries(coords, mode, radius)
    local resource = GetInvokingResource()

    if type(coords) ~= 'vector3' then
        return nil, ('coords must be a vector3 (received %s)'):format(type(coords))
    end

    if mode == 'single' then
        local ids = getEntriesInRange(generic, coords.x - CELL_SIZE, coords.y - CELL_SIZE, coords.x + CELL_SIZE, coords.y + CELL_SIZE)

        local nearest
        local nearestDistance = math.huge
        for id in pairs(ids) do
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
    elseif mode == 'radius' then
        if type(radius) ~= 'number' then
            return nil, ('radius must be a number (received %s)'):format(type(radius))
        end

        local ids = getEntriesInRange(generic, coords.x - radius, coords.y - radius, coords.x + radius, coords.y + radius)
        local result = {}
        for id in pairs(ids) do
            if entries[id] and entries[id].resource == resource then
                result[#result + 1] = entries[id]
            end
        end

        return result
    else
        return nil, ('unknown "%s" mode received'):format(mode)
    end
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
exports('GetEntries', getEntries)