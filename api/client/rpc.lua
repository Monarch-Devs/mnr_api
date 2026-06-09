local TIMEOUT = GetConvarInt('mnr_api:rpc_timeout', 10000)

local waiting = {}
local seq = 0

local function makeKey(name)
    seq += 1

    return ('%s|%d'):format(name, seq)
end

local function resolveMs(timeout)
    if timeout == false then
        return nil
    end

    return (type(timeout) == 'number' and timeout > 0) and timeout or TIMEOUT
end

RegisterNetEvent(('mnr:reply:%s'):format(mnrEnv.resource), function(key, ok, ...)
    if GetInvokingResource() or source ~= 65535 then return end

    local slot = waiting[key]
    if not slot then return end

    waiting[key] = nil
    slot(ok, ...)
end)

---@class MnrClientRPC
local rpc = {}

function rpc.send(name, timeout, cb, ...)
    if type(name) ~= 'string' then return error(('rpc.send: name must be a string, got "%s"'):format(type(name)), 2) end
    if type(cb) ~= 'function' then return error(('rpc.send: cb must be a function, got "%s"'):format(type(cb)), 2) end

    local key = makeKey(name)
    waiting[key] = cb

    TriggerServerEvent(('mnr:invoke:%s'):format(name), mnrEnv.resource, key, ...)

    local ms = resolveMs(timeout)
    if ms then
        SetTimeout(ms, function()
            if not waiting[key] then return end
            waiting[key] = nil
            print(('^1RPC "%s" timed out after %dms^0'):format(name, ms))
        end)
    end
end

function rpc.fetch(name, timeout, ...)
    if type(name) ~= 'string' then return error(('rpc.fetch: name must be a string, got "%s"'):format(type(name)), 2) end

    local key = makeKey(name)
    local p = promise.new()

    waiting[key] = function(ok, ...)
        if ok then
            p:resolve({ ... })
        else
            p:reject(tostring((...)))
        end
    end

    TriggerServerEvent(('mnr:invoke:%s'):format(name), mnrEnv.resource, key, ...)

    local ms = resolveMs(timeout)
    if ms then
        SetTimeout(ms, function()
            if not waiting[key] then return end
            waiting[key] = nil
            p:reject(('RPC "%s" timed out after %dms'):format(name, ms))
        end)
    end

    return table.unpack(Citizen.Await(p))
end

function rpc.handle(name, handler)
    if type(name) ~= 'string' then return error(('rpc.handle: name must be a string, got "%s"'):format(type(name)), 2) end
    if type(handler) ~= 'function' then return error(('rpc.handle: handler must be a function, got "%s"'):format(type(handler)), 2) end

    RegisterNetEvent(('mnr:invoke:%s'):format(name), function(resource, key, ...)
        if GetInvokingResource() or source ~= 65535 then return end

        if type(resource) ~= 'string' or resource == '' then return end

        local res = table.pack(pcall(handler, ...))
        local ok = res[1]

        if not ok then
            print(('^1RPC handler "%s" error: %s^0'):format(name, res[2]))
            TriggerServerEvent(('mnr:reply:%s'):format(resource), key, false, tostring(res[2]))
            return
        end

        TriggerServerEvent(('mnr:reply:%s'):format(resource), key, true, table.unpack(res, 2, res.n))
    end)
end

return rpc