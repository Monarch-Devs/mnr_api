local existing = rawget(_ENV, 'mnr')
if existing and existing.name == 'mnr_api' then
    error(('mnr_api already loaded in %s - remove duplicate "@mnr_api/api.lua" from fxmanifest.lua'):format(GetCurrentResourceName()))
end

local registry = {}
local pending = {}
local pendingCount = 0
local ready = false
local loading = {}

local TIMEOUT = GetConvarInt('mnr_api:api_timeout', 30000)
local scope = IsDuplicityVersion() and 'server' or 'client'

msgpack.setoption('ignore_invalid', true)

local apiEnvMeta = {
    __index = _ENV,
}

local function buildAPIEnv()
    return setmetatable({}, apiEnvMeta)
end

local function loadAPI(key)
    local scopedPath = ('api/%s/%s.lua'):format(scope, key)
    local sharedPath = ('api/shared/%s.lua'):format(key)
    local path = scopedPath
    local code = LoadResourceFile('mnr_api', path)

    if not code then
        path = sharedPath
        code = LoadResourceFile('mnr_api', path)
    end

    if not code then return end

    local fn, err = load(code, ('@@mnr_api/%s'):format(path), 't', buildAPIEnv())

    if not fn then
        error(('Failed importing API (%s): %s'):format(path, err), 3)
    end

    local ok, result = pcall(fn)

    if not ok then
        error(('Failed executing API (%s): %s'):format(path, result), 3)
    end

    return result
end

local function resolveKey(key)
    local cached = registry[key]

    if cached and cached ~= loading then
        return cached
    end

    if cached == loading then
        error(('Circular dependency detected on key: %s'):format(key), 2)
    end

    registry[key] = loading

    local ok, api = pcall(loadAPI, key)
    if not ok then
        registry[key] = nil
        error(api, 2)
    end

    if not api then
        registry[key] = nil
        error(('API "%s" not found in api/%s/ or api/shared/'):format(key, scope), 2)
    end

    registry[key] = api

    return api
end

local function abortPending()
    local snapshot = pending
    local count = pendingCount
    pending = {}
    pendingCount = 0

    for i = 1, count do
        coroutine.resume(snapshot[i], nil, 'Aborted: mnr_api did not start in time')
    end
end

local function initAPI()
    ready = true

    local snapshot = pending
    local count = pendingCount
    pending = {}
    pendingCount = 0

    for i = 1, count do
        coroutine.resume(snapshot[i])
    end
end

local function waitReady(key)
    if ready then return end

    local co = coroutine.running()
    if not co then
        error(('mnr.%s accessed outside a coroutine before mnr_api was ready'):format(key), 2)
    end

    pendingCount = pendingCount + 1
    pending[pendingCount] = co

    local _, err = coroutine.yield()
    if err then error(err, 2) end
end

---@type MnrAPI
local mnr = setmetatable({}, {
    __index = function(_, key)
        if key == 'name' then
            return 'mnr_api'
        end

        if key == 'scope' then
            return scope
        end

        local cached = registry[key]
        if cached and cached ~= loading then
            return cached
        end

        if ready then
            return resolveKey(key)
        end

        local stub = setmetatable({}, {
            __index = function(_, field)
                waitReady(key)
                local api = resolveKey(key)
                rawset(mnr, key, api)
                return api[field]
            end,
            __call = function(_, ...)
                waitReady(key)
                local api = resolveKey(key)
                rawset(mnr, key, api)
                return api(...)
            end,
            __metatable = false,
        })

        rawset(mnr, key, stub)

        return stub
    end,
    __newindex = function(_, key, value)
        registry[key] = value
    end,
    __metatable = false,
})

local mnrEnv = setmetatable({ resource = GetCurrentResourceName() }, {
    __index = function(_, key)
        local ok, value = pcall(exports.mnr_api.getEnv, nil, key)
        if not ok then
            error(('mnrEnv.%s is not available'):format(key), 2)
        end

        return value
    end,
    __metatable = false,
})

local startEvent = IsDuplicityVersion() and 'onResourceStart' or 'onClientResourceStart'
local timer
local handler

handler = AddEventHandler(startEvent, function(name)
    if name ~= 'mnr_api' then return end

    RemoveEventHandler(handler)
    if timer then
        ClearTimeout(timer)
    end

    initAPI()
end)

CreateThread(function()
    if GetResourceState('mnr_api') == 'started' then
        RemoveEventHandler(handler)
        initAPI()
        return
    end

    timer = SetTimeout(TIMEOUT, function()
        RemoveEventHandler(handler)
        abortPending()

        error(('Timeout: mnr_api did not start within %dms - stopping %s'):format(TIMEOUT, GetCurrentResourceName()), 0)
    end)
end)

rawset(_ENV, 'mnr', mnr)
rawset(_ENV, 'mnrEnv', mnrEnv)