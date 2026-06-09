local RENAME = GetConvarBool('mnr_api:rename_checker', true)
local UPDATE = GetConvarBool('mnr_api:update_checker', true)

if not RENAME and not UPDATE then return end

local SERVICES = {
    github = 'https://github.com/%s/%s',
    gitlab = 'https://gitlab.com/%s/%s',
}

local VALID_URLS = {
    '^https://raw%.githubusercontent%.com/',
    '^https://gitlab%.com/.+/%-/raw/.+',
}

---@param url string
---@return boolean isValid
local function isValidUrl(url)
    for i = 1, #VALID_URLS do
        if url:match(VALID_URLS[i]) then
            return true
        end
    end

    return false
end

---@param v string
---@return integer, integer, integer
local function parseSemver(v)
    local a, b, c = v:match('^v?(%d+)%.(%d+)%.(%d+)$')

    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

---@param a string
---@param b string
---@return boolean
local function semverGt(a, b)
    local a1, a2, a3 = parseSemver(a)
    local b1, b2, b3 = parseSemver(b)

    if a1 ~= b1 then return a1 > b1 end
    if a2 ~= b2 then return a2 > b2 end

    return a3 > b3
end

---@param service 'github' | 'gitlab'
---@param account string
---@param name string
---@param version string
---@return string | false
local function buildReleaseLink(service, account, name, version)
    local base = SERVICES[service]
    if not base then return false end

    return ('%s/releases/tag/v%s'):format(base:format(account, name), version)
end

---@param name string
---@param url string
---@param results table
---@param done fun()
local function checkResource(name, url, results, done)
    if not isValidUrl(url) then
        results[#results + 1] = ('^1[!!] "%s" checker URL is not allowed: %s^0'):format(name, url)
        return done()
    end

    PerformHttpRequest(url, function(status, body)
        if status ~= 200 or not body then
            results[#results + 1] = ('^3[CHECKER] Failed to fetch version.json for "%s" (HTTP %d)^0'):format(name, status)
            return done()
        end

        local data = json.decode(body)
        if type(data) ~= 'table' then
            results[#results + 1] = ('^3[CHECKER] Invalid version.json for "%s"^0'):format(name)
            return done()
        end

        local canonicalName = type(data.name) == 'string' and data.name:match('^[%w_%-]+$') and data.name or nil
        local account = type(data.account) == 'string' and data.account:match('^[%w_%-]+$') and data.account or nil
        local service = type(data.service) == 'string' and SERVICES[data.service] and data.service or nil

        if RENAME then
            if not canonicalName then
                results[#results + 1] = ('^3[CHECKER] Missing or invalid "name" in version.json for "%s"^0'):format(name)
            elseif canonicalName ~= name then
                results[#results + 1] = ('^1[!] "%s" named wrong, rename it to "%s"^0'):format(name, canonicalName)
            end
        end

        if UPDATE and type(data.version) == 'string' then
            local latest = data.version:match('^v?(%d+%.%d+%.%d+)$')
            if not latest then
                results[#results + 1] = ('^3[CHECKER] Invalid version format in version.json for "%s"^0'):format(name)
                return done()
            end

            local current = GetResourceMetadata(name, 'version', 0) or '0.0.0'
            local link = (service and account and canonicalName) and buildReleaseLink(service, account, canonicalName, latest) or false
            local linkStr = link and (' [%s]'):format(link) or ''

            if semverGt(latest, current) then
                results[#results + 1] = ('^3[?] "%s" update [%s < %s]%s^0'):format(name, current, latest, linkStr)
            else
                results[#results + 1] = ('^2[+] "%s" up to date [%s = %s]^0'):format(name, current, latest)
            end
        end

        done()
    end, 'GET', '', { ['Cache-Control'] = 'no-cache', ['Pragma'] = 'no-cache' })
end

local function makeHeader(text)
    local inner = (' %s '):format(text)
    local left = math.floor((100 - #inner) / 2)

    return ('^5%s%s%s^0'):format(('='):rep(left), inner, ('='):rep(100 - #inner - left))
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

        print(makeHeader(('MONARCH CHECKER START [%s]'):format(os.date('%d/%m/%Y %H:%M:%S'))))
        for i = 1, #results do
            print(results[i])
        end
        print(makeHeader(('MONARCH CHECKER ENDED (%d/%d)'):format(completed, total)))

        results = nil
        toCheck = nil
    end

    for i = 1, total do
        Wait(100)
        checkResource(toCheck[i].name, toCheck[i].url, results, done)
    end
end)