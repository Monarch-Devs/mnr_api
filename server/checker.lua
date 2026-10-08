local RENAME = GetConvarBool('mnr_api:rename_checker', true)
local UPDATE = GetConvarBool('mnr_api:update_checker', true)

if not RENAME and not UPDATE then return end

local SERVICES = {
    github = '[https://github.com/%s/%s]',
    gitlab = '[https://gitlab.com/%s/%s]',
}

---@param url string
---@return boolean valid
local function validateUrl(url)
    if url:match('^https://raw%.githubusercontent%.com/') then
        return true
    end

    return url:match('^https://gitlab%.com/.+/%-/raw/.+') ~= nil
end

---@param version string
---@return number? major, number? minor, number? patch
local function parseVersion(version)
    local major, minor, patch = version:match('^v?(%d+)%.(%d+)%.(%d+)$')

    if not major then
        return nil
    end

    return tonumber(major), tonumber(minor), tonumber(patch)
end

---@param latest string
---@param actual string
---@return -1 | 0 | 1 | false
local function compareVersions(latest, actual)
    local a1, a2, a3 = parseVersion(latest)
    local b1, b2, b3 = parseVersion(actual)

    if not a1 or not b1 then
        return false
    end

    if a1 ~= b1 then
        return a1 > b1 and 1 or -1
    end

    if a2 ~= b2 then
        return a2 > b2 and 1 or -1
    end

    if a3 ~= b3 then
        return a3 > b3 and 1 or -1
    end

    return 0
end

---@param service 'github' | 'gitlab' | nil
---@param account string?
---@param name string?
---@return string repository
local function buildRepositoryLink(service, account, name)
    if not SERVICES[service] then
        return '[UNKNOWN SERVICE]'
    end

    if not account then
        return '[UNKNOWN ACCOUNT]'
    end

    if not name then
        return '[UNKNOWN REPOSITORY]'
    end

    return SERVICES[service]:format(account, name)
end

local CASES = {
    [false] = '^1[!!!] "%s" has a malformed version [local: %s | remote: %s] %s^0',
    [-1] = '^2[>] "%s" local newer [%s > %s] %s^0',
    [0] = '^2[=] "%s" up to date [%s = %s] %s^0',
    [1] = '^3[<] "%s" update [%s < %s] %s^0',
}

---@param name string
---@param url string
---@param results table
---@param done fun()
local function checkResource(name, url, results, done)
    if not validateUrl(url) then
        results[#results + 1] = ('^1[!!] "%s" checker URL is not allowed: %s^0'):format(name, url)
        return done()
    end

    PerformHttpRequest(url, function(status, body)
        if status ~= 200 or not body then
            results[#results + 1] = ('^3[!!!] Failed to fetch version.json for "%s"^0'):format(name)
            return done()
        end

        local data = json.decode(body)
        if type(data) ~= 'table' then
            results[#results + 1] = ('^3[!!!] Invalid version.json for "%s"^0'):format(name)
            return done()
        end

        local canonicalName = type(data.name) == 'string' and data.name:match('^[%w_%-]+$') and data.name or nil
        local account = type(data.account) == 'string' and data.account:match('^[%w_%-]+$') and data.account or nil
        local service = type(data.service) == 'string' and SERVICES[data.service] and data.service or nil

        if RENAME then
            if not canonicalName then
                results[#results + 1] = ('^3[!!!] Missing or invalid "name" in version.json for "%s"^0'):format(name)
            elseif canonicalName ~= name then
                results[#results + 1] = ('^1[!] "%s" named wrong, rename it to "%s"^0'):format(name, canonicalName)
            end
        end

        if UPDATE and type(data.version) == 'string' then
            local actual = GetResourceMetadata(name, 'version', 0) or '0.0.0'
            local repository = buildRepositoryLink(service, account, canonicalName)

            local comparison = compareVersions(data.version, actual)
            results[#results + 1] = CASES[comparison]:format(name, actual, data.version, repository)
        end

        done()
    end, 'GET', '', { ['Cache-Control'] = 'no-cache', ['Pragma'] = 'no-cache' })
end

CreateThread(function()
    Wait(2000)

    local toCheck = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then
            local url = GetResourceMetadata(name, 'checker', 0)
            if type(url) == 'string' and url ~= '' then
                toCheck[#toCheck + 1] = { name = name, url = url }
            end
        end
    end

    local total = #toCheck
    if total == 0 then return end

    local results = {}
    local completed = 0

    local function done()
        completed += 1
        if completed < total then return end

        print(('^5> MONARCH RESOURCES CHECKER [%s]^0'):format(os.date('%d/%m/%Y %H:%M:%S')))

        for i = 1, #results do
            print(results[i])
        end

        print('^5> MONARCH RESOURCES CHECKER [COMPLETE]^0')

        results = nil
        toCheck = nil
    end

    for i = 1, total do
        Wait(100)
        checkResource(toCheck[i].name, toCheck[i].url, results, done)
    end
end)