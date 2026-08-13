---@class OPTS
---@field resource string
---@field scope 'client' | 'server'
---@field readFile fun(path: string): string?

---@param opts OPTS
---@return fun(key: string): any resolveKey, table registry, table loading
local function buildResolver(opts)
    local registry = {}
    local loading = {}

    local apiEnvMeta = { __index = _ENV }

    local function buildAPIEnv()
        return setmetatable({}, apiEnvMeta)
    end

    local function loadAPI(key)
        local scopedPath = ('api/%s/%s.lua'):format(opts.scope, key)
        local sharedPath = ('api/shared/%s.lua'):format(key)
        local path = scopedPath
        local code = opts.readFile(path)

        if not code then
            path = sharedPath
            code = opts.readFile(path)
        end

        if not code then return end

        local fn, err = load(code, ('@@%s/%s'):format(opts.resource, path), 't', buildAPIEnv())

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
            error(('API "%s" not found in api/%s/ or api/shared/'):format(key, opts.scope), 2)
        end

        registry[key] = api

        return api
    end

    return resolveKey, registry, loading
end

return buildResolver