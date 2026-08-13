---@description This is an internal process that gives the possibility to use the API's internally (Don't declare it in external resources)

if rawget(_ENV, 'mnr') then return end

local scope = IsDuplicityVersion() and 'server' or 'client'

local buildResolver = LoadResourceFile('mnr_api', 'api/loader.lua')
buildResolver = assert(load(buildResolver, '@@mnr_api/api/loader.lua', 't'))()

local resolveKey, registry = buildResolver({
    resource = 'mnr_api',
    scope = scope,
    readFile = function(path)
        return LoadResourceFile('mnr_api', path)
    end,
})

---@type MnrAPI
local mnr = setmetatable({}, {
    __index = function(_, key)
        if key == 'name' then
            return 'mnr_api'
        end

        if key == 'scope' then
            return scope
        end

        return resolveKey(key)
    end,
    __newindex = function(_, key, value)
        registry[key] = value
    end,
    __metatable = false,
})

local mnrEnv = setmetatable({ resource = GetCurrentResourceName() }, {
    __index = function(_, field)
        local source = rawget(_ENV, '_MnrEnvSource')
        local value = source and source[field]

        if value == nil or type(value) == 'function' then
            error(('mnrEnv.%s is not available'):format(field), 2)
        end

        return value
    end,
    __metatable = false,
})

rawset(_ENV, 'mnr', mnr)
rawset(_ENV, 'mnrEnv', mnrEnv)