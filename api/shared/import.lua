local cached = {}
local loading = {}

---@type MnrImportAPI
local function import(path, ext, cache, env)
    if type(path) ~= 'string' then error(('Path must be a string, received %s'):format(type(path)), 2) end
    if ext ~= 'lua' and ext ~= 'json' then error(('Unsupported extension "%s", expected "lua" or "json"'):format(tostring(ext)), 2) end

    local key = ('%s|%s'):format(path, ext)
    if loading[key] then
        error(('Circular dependency detected while loading "%s"'):format(path), 2)
    end

    if cache and cached[key] ~= nil then
        return cached[key]
    end

    loading[key] = true

    local file = LoadResourceFile(mnrEnv.resource, ('%s.%s'):format(path, ext))
    if not file then
        loading[key] = nil
        error(('No file "%s.%s"'):format(path, ext), 2)
    end

    local result
    if ext == 'json' then
        result = json.decode(file)
    else
        local chunk, err = load(file, ('@@%s/%s.lua'):format(mnrEnv.resource, path), 't', env)
        if not chunk then
            loading[key] = nil
            error(('Failed loading "%s": %s'):format(path, err), 2)
        end

        result = chunk()
    end

    loading[key] = nil

    if cache and result ~= nil and result ~= false then
        cached[key] = result
    end

    return result
end

return import