local PlayerPedId = PlayerPedId
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetPedInVehicleSeat = GetPedInVehicleSeat
local GetVehicleMaxNumberOfPassengers = GetVehicleMaxNumberOfPassengers

local env = { playerId = PlayerId(), ped = 0, vehicle = 0, seat = false }
local _seatDirty = false

---@param field string
---@param value any
function env:update(field, value)
    if self[field] == value then return end

    self[field] = value
    TriggerEvent(('mnr_api:update:%s'):format(field), value)
end

---@return integer | false
function env:scanSeat()
    for slot = -1, GetVehicleMaxNumberOfPassengers(self.vehicle) - 1 do
        if GetPedInVehicleSeat(self.vehicle, slot) == self.ped then
            return slot
        end
    end

    return false
end

function env:syncSeat()
    if not _seatDirty and self.seat ~= false and GetPedInVehicleSeat(self.vehicle, self.seat) == self.ped then
        return
    end

    self:update('seat', self:scanSeat())
    _seatDirty = false
end

function env:syncVehicle()
    local vehicle = GetVehiclePedIsIn(self.ped, false)

    if vehicle ~= self.vehicle then
        _seatDirty = true
        self:update('vehicle', vehicle)
    end

    if vehicle == 0 then
        self:update('seat', false)
        _seatDirty = false
        return
    end

    self:syncSeat()
end

---@return 100 | 200 | 500 delay
function env:poll()
    self:update('ped', PlayerPedId())

    if self.ped == 0 then
        return 500
    end

    self:syncVehicle()

    return self.vehicle ~= 0 and 100 or 200
end

CreateThread(function()
    while true do
        Wait(env:poll())
    end
end)

rawset(_ENV, 'mnrEnv', env)

---@param key string
exports('getEnv', function(key)
    if type(key) ~= 'string' then
        error(('Key must be a string, received "%s"'):format(type(key)))
    end

    if env[key] == nil or type(env[key]) == 'function' then
        error(('Unknown environment variable "%s"'):format(key))
    end

    return env[key]
end)