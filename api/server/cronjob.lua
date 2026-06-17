local jobs = {}
local listenerRegistered = false

---@param resource string
local function ensureListener(resource)
    if listenerRegistered then return end
    listenerRegistered = true

    AddEventHandler(('mnr:cronjob:%s'):format(resource), function(schedulerId, firedAt)
        local callback = jobs[schedulerId]
        if not callback then return end

        local d = os.date('*t', firedAt)
        Citizen.CreateThreadNow(function()
            local ok, err = pcall(callback, d)
            if not ok then
                mnr.debug('error', 'Job %s error: %s', schedulerId, err)
            end
        end)
    end)

    AddEventHandler(('mnr:cronjob:%s:missed'):format(resource), function(schedulerId, delta)
        if not jobs[schedulerId] then return end
        mnr.debug('debug', 'Job %s missed by %ss, skipping', schedulerId, delta)
    end)

    AddEventHandler(('mnr:cronjob:%s:expired'):format(resource), function(schedulerId)
        jobs[schedulerId] = nil
    end)
end

---@class MnrCronjob
local MnrCronjob = {}
MnrCronjob.__index = MnrCronjob

---@return boolean
function MnrCronjob:stop()
    if not jobs[self.schedulerId] then return false end

    local ok = exports.mnr_api:UnregisterCronjob(mnrEnv.resource, self.schedulerId)
    if ok then
        jobs[self.schedulerId] = nil
    end

    return ok == true
end

local function cronjob(expression, callback, options)
    if type(expression) ~= 'string' then error(('expression must be string, got %s'):format(type(expression)), 2) end
    if type(callback) ~= 'function' then error(('callback must be function, got %s'):format(type(callback)), 2) end

    local maxDelay = options and options.maxDelay
    if type(maxDelay) ~= 'number' or maxDelay < 0 then
        error('options.maxDelay is required and must be a non-negative number (0 to disable delay check)', 2)
    end

    ensureListener(mnrEnv.resource)

    local schedulerId, err = exports.mnr_api:RegisterCronjob(mnrEnv.resource, expression, maxDelay)
    if not schedulerId then
        error(('failed to register cronjob "%s": %s'):format(expression, err or 'unknown error'), 2)
    end

    local handle = setmetatable({
        schedulerId = schedulerId,
        expression  = expression,
    }, MnrCronjob)

    jobs[schedulerId] = callback

    return handle
end

return cronjob