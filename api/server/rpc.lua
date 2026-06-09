local TIMEOUT = GetConvarInt('mnr_api:rpc_timeout', 10000)

local waiting = {}
local waitingByPlayer = {}
local seq = 0

local function makeKey(name, playerId)
    seq += 1

    return ('%s|%d|%d'):format(name, seq, playerId)
end

local function clearKey(key, playerId)
    waiting[key] = nil

    local byPlayer = waitingByPlayer[playerId]
    if byPlayer then
        byPlayer[key] = nil
    end
end

local function trackKey(key, playerId)
    if not waitingByPlayer[playerId] then
        waitingByPlayer[playerId] = {}
    end

    waitingByPlayer[playerId][key] = true
end

local function resolveMs(timeout)
    if timeout == false then
        return nil
    end

    return (type(timeout) == 'number' and timeout > 0) and timeout or TIMEOUT
end

RegisterNetEvent(('mnr:reply:%s'):format(mnrEnv.resource), function(key, ok, ...)
    local src = source
    if GetInvokingResource() then return end

    local byPlayer = waitingByPlayer[src]
    if not byPlayer or not byPlayer[key] then return end

    local slot = waiting[key]
    if not slot then return end

    clearKey(key, src)
    slot(ok, ...)
end)

---@class MnrServerRPC
local rpc = {}

function rpc.send(name, playerId, timeout, cb, ...)
    if type(name) ~= 'string' then return error(('rpc.send: name must be a string, got "%s"'):format(type(name)), 2) end
    if type(playerId) ~= 'number' then return error(('rpc.send: playerId must be a number, got "%s"'):format(type(playerId)), 2) end
    if type(cb) ~= 'function' then return error(('rpc.send: cb must be a function, got "%s"'):format(type(cb)), 2) end
    if not DoesPlayerExist(playerId) then return error(('rpc.send: player "%d" does not exist'):format(playerId), 2) end

    local key = makeKey(name, playerId)
    waiting[key] = cb
    trackKey(key, playerId)

    TriggerClientEvent(('mnr:invoke:%s'):format(name), playerId, mnrEnv.resource, key, ...)

    local ms = resolveMs(timeout)
    if ms then
        SetTimeout(ms, function()
            if not waiting[key] then return end
            clearKey(key, playerId)
            print(('^1RPC "%s" timed out after %dms for player %d^0'):format(name, ms, playerId))
        end)
    end
end

function rpc.fetch(name, playerId, timeout, ...)
    if type(name) ~= 'string' then return error(('rpc.fetch: name must be a string, got "%s"'):format(type(name)), 2) end
    if type(playerId) ~= 'number' then return error(('rpc.fetch: playerId must be a number, got "%s"'):format(type(playerId)), 2) end
    if not DoesPlayerExist(playerId) then return error(('rpc.fetch: player "%d" does not exist'):format(playerId), 2) end

    local key = makeKey(name, playerId)
    local p = promise.new()

    waiting[key] = function(ok, ...)
        if ok then
            p:resolve({ ... })
        else
            p:reject(tostring((...)))
        end
    end
    trackKey(key, playerId)

    TriggerClientEvent(('mnr:invoke:%s'):format(name), playerId, mnrEnv.resource, key, ...)

    local ms = resolveMs(timeout)
    if ms then
        SetTimeout(ms, function()
            if not waiting[key] then return end
            clearKey(key, playerId)
            p:reject(('RPC "%s" timed out after %dms for player %d'):format(name, ms, playerId))
        end)
    end

    return table.unpack(Citizen.Await(p))
end

function rpc.handle(name, handler)
    if type(name) ~= 'string' then return error(('rpc.handle: name must be a string, got "%s"'):format(type(name)), 2) end
    if type(handler) ~= 'function' then return error(('rpc.handle: handler must be a function, got "%s"'):format(type(handler)), 2) end

    RegisterNetEvent(('mnr:invoke:%s'):format(name), function(resource, key, ...)
        local src = source
        if GetInvokingResource() then return end
        if not DoesPlayerExist(src) then return end
        if type(resource) ~= 'string' or GetResourceState(resource) ~= 'started' then return end

        local res = table.pack(pcall(handler, src, ...))
        local ok = res[1]

        if not ok then
            print(('^1RPC handler "%s" error for player %d: %s^0'):format(name, src, res[2]))
            TriggerClientEvent(('mnr:reply:%s'):format(resource), src, key, false, tostring(res[2]))
            return
        end

        TriggerClientEvent(('mnr:reply:%s'):format(resource), src, key, true, table.unpack(res, 2, res.n))
    end)
end

AddEventHandler('playerDropped', function()
    local src = source
    local keys = waitingByPlayer[src]
    if not keys then return end

    for key in pairs(keys) do
        waiting[key] = nil
    end

    waitingByPlayer[src] = nil
end)

return rpc