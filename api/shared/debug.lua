local LOG_LEVELS = {
    debug = { severity = 1, badge = '[-]', color = '^5' },
    info  = { severity = 2, badge = '[i]', color = '^4' },
    warn  = { severity = 3, badge = '[?]', color = '^3' },
    error = { severity = 4, badge = '[!]', color = '^1' },
    fatal = { severity = 5, badge = '[x]', color = '^8' },
}

local function getSeverity()
    local scriptSeverity = GetConvar(('mnr_api:debug_severity:%s'):format(mnrEnv.resource), '_unset')
    local globalSeverity = GetConvar('mnr_api:debug_severity', '_unset')

    local level = scriptSeverity ~= '_unset' and scriptSeverity or globalSeverity
    local logLevel = LOG_LEVELS[level]

    return logLevel and logLevel.severity or 0
end

local SEVERITY = getSeverity()

AddConvarChangeListener('mnr_api:debug_severity', function()
    SEVERITY = getSeverity()
end)

AddConvarChangeListener(('mnr_api:debug_severity:%s'):format(mnrEnv.resource), function()
    SEVERITY = getSeverity()
end)

local function serialize(v)
    if type(v) == 'table' then
        return json.encode(v)
    end

    return tostring(v)
end

local function formatMessage(text, ...)
    local args = table.pack(...)

    for i = 1, args.n do
        args[i] = serialize(args[i])
    end

    return text:format(table.unpack(args, 1, args.n))
end

local function debug(level, text, ...)
    if SEVERITY == 0 then return end

    local logLevel = LOG_LEVELS[level]
    if not logLevel or SEVERITY < logLevel.severity then return end

    if type(text) ~= 'string' then
        error(('text must be a string, received %s'):format(type(text)), 2)
    end

    local n = select('#', ...)
    local message = n > 0 and formatMessage(text, ...) or text

    print(('%s%s %s^0'):format(logLevel.color, logLevel.badge, message))
end

return debug