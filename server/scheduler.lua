local WEEK_MAP = { sun = 1, mon = 2, tue = 3, wed = 4, thu = 5, fri = 6, sat = 7 }
local MONTH_MAP = { jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12 }
local LIMITS = {
    min = { 0, 59 },
    hour = { 0, 23 },
    day = { 1, 31 },
    month = { 1, 12 },
    wday = { 1, 7 },
}

--[[ [LOOP LOOKUP OPTIMIZATION] STRUCTURE (before I get melt)

    schedule[timestamp] = {
        { resource, schedulerId },
        { resource, schedulerId },
    }
]]
local schedule = {}

--[[ [REMOVAL OPTIMIZATION] STRUCTURE
    index[schedulerId] = { timestamp, arrayPos }
]]
local index = {}
local taskCount = 0
local currentSID = 0

---@param raw string
---@param unit string
---@return number?
local function resolveValue(raw, unit)
    local n = tonumber(raw)
    if n then
        return n
    end

    if unit == 'wday' then
        return WEEK_MAP[raw]
    end
    if unit == 'month' then
        return MONTH_MAP[raw]
    end

    return nil
end

---@param raw string?
---@param unit string
---@return table?, string?
local function parseField(raw, unit)
    if not raw or raw == '*' then return nil, nil end

    local r = LIMITS[unit]

    if unit == 'day' and raw == 'l' then
        return { type = 'lastday' }, nil
    end

    local stepStr = raw:match('^%*/(%d+)$')
    if stepStr then
        local s = tonumber(stepStr)
        if not s or s == 0 then
            return nil, ('invalid step "%s" for %s'):format(raw, unit)
        end

        return { type = 'step', step = s }, nil
    end

    local wa, wb = raw:match('^(%a+)-(%a+)$')
    if wa and wb and unit == 'wday' then
        local a, b = WEEK_MAP[wa], WEEK_MAP[wb]
        if not a or not b then
            return nil, ('invalid weekday range "%s"'):format(raw)
        end

        return { type = 'range', min = a, max = b }, nil
    end

    local lo, hi = raw:match('^(%d+)-(%d+)$')
    if lo and hi then
        lo, hi = tonumber(lo), tonumber(hi)
        if lo < r[1] or hi > r[2] or lo > hi then
            return nil, ('invalid range "%s" for %s'):format(raw, unit)
        end

        return { type = 'range', min = lo, max = hi }, nil
    end

    if raw:find(',') then
        local values = {}
        for seg in raw:gmatch('[^,]+') do
            local n = resolveValue(seg, unit)
            if not n or n < r[1] or n > r[2] then
                return nil, ('invalid list value "%s" for %s'):format(seg, unit)
            end
            values[n] = true
        end

        return { type = 'list', values = values }, nil
    end

    local n = resolveValue(raw, unit)
    if not n or n < r[1] or n > r[2] then
        return nil, ('invalid value "%s" for %s'):format(raw, unit)
    end

    return { type = 'number', value = n }, nil
end

---@param field table?
---@param value number
---@return boolean
local function matches(field, value)
    if not field then
        return true
    end

    if field.type == 'number' then
        return field.value == value
    end
    if field.type == 'list' then
        return field.values[value] == true
    end
    if field.type == 'range' then
        return value >= field.min and value <= field.max
    end
    if field.type == 'step' then
        return value % field.step == 0
    end

    return false
end

---@param field table?
---@param cur number
---@param maxVal number
---@return number?
local function nextMatch(field, cur, maxVal)
    if not field then
        return cur
    end

    if field.type == 'step' then
        local rem = cur % field.step
        local v = rem == 0 and cur or cur + (field.step - rem)

        return v <= maxVal and v or nil
    end

    if field.type == 'number' then
        return cur <= field.value and field.value <= maxVal and field.value or nil
    end

    if field.type == 'range' then
        if cur > field.max then
            return nil
        end

        return cur < field.min and field.min or cur
    end

    if field.type == 'list' then
        for v = cur, maxVal do
            if field.values[v] then
                return v
            end
        end

        return nil
    end

    return nil
end

---@param month number
---@param year number
---@return number
local function monthDays(month, year)
    return os.date('*t', os.time({ year = year, month = month + 1, day = 0, hour = 0, min = 0, sec = 0 })).day
end

---@param task table
---@param startDay number
---@param month number
---@param year number
---@param maxDay number
---@return number?
local function nextDay(task, startDay, month, year, maxDay)
    if task._day and task._day.type == 'lastday' then
        return startDay <= maxDay and maxDay or nil
    end

    local hasDom = task._day ~= nil
    local hasWday = task._wday ~= nil
    local wd = tonumber(os.date('%w', os.time({ year = year, month = month, day = startDay, hour = 0, min = 0, sec = 0 }))) + 1

    for d = startDay, maxDay do
        local matched
        if hasDom and hasWday then
            matched = matches(task._day, d) or matches(task._wday, wd)
        elseif hasDom then
            matched = matches(task._day, d)
        elseif hasWday then
            matched = matches(task._wday, wd)
        else
            matched = true
        end

        if matched then
            return d
        end

        wd = wd % 7 + 1
    end

    return nil
end

---@param year number
---@param month number
---@param day number
---@param mdays number
---@return number, number, number
local function advanceDay(year, month, day, mdays)
    day = day + 1
    if day > mdays then
        month, day = month + 1, 1
        if month > 12 then
            year, month = year + 1, 1
        end
    end

    return year, month, day
end

---@param year number
---@param month number
---@param day number
---@param hour number
---@param mdays number
---@return number, number, number, number
local function advanceHour(year, month, day, hour, mdays)
    hour = hour + 1
    if hour > 23 then
        year, month, day = advanceDay(year, month, day, mdays)
        hour = 0
    end

    return year, month, day, hour
end

---@param task table
---@param year number
---@param month number
---@param day number
---@param hour number
---@param min number
---@return boolean, number, number, number, number, number
local function stepNextRun(task, year, month, day, hour, min)
    local mo = nextMatch(task._month, month, 12)
    if not mo then
        return false, year + 1, 1, 1, 0, 0
    end
    if mo > month then
        return false, year, mo, 1, 0, 0
    end

    local mdays = monthDays(month, year)
    local d = nextDay(task, day, month, year, mdays)
    if not d then
        local nm = month + 1
        if nm > 12 then
            return false, year + 1, 1, 1, 0, 0
        end

        return false, year, nm, 1, 0, 0
    end
    if d > day then
        return false, year, month, d, 0, 0
    end

    local hr = nextMatch(task._hour, hour, 23)
    if not hr then
        local ny, nm, nd = advanceDay(year, month, day, mdays)

        return false, ny, nm, nd, 0, 0
    end
    if hr > hour then
        return false, year, month, day, hr, 0
    end

    local mn = nextMatch(task._min, min, 59)
    if not mn then
        local ny, nm, nd, nh = advanceHour(year, month, day, hour, mdays)

        return false, ny, nm, nd, nh, 0
    end

    return true, year, month, day, hour, mn
end

---@param task table
---@param after number
---@return number?
local function calcNextRun(task, after)
    local base = after - (after % 60) + 60
    local t = os.date('*t', base)
    local year, month, day, hour, min = t.year, t.month, t.day, t.hour, t.min
    local yearLimit = year + 4

    while year <= yearLimit do
        local found, ny, nm, nd, nh, nmn = stepNextRun(task, year, month, day, hour, min)

        if found then
            return os.time({ year = ny, month = nm, day = nd, hour = nh, min = nmn, sec = 0 })
        end

        year, month, day, hour, min = ny, nm, nd, nh, nmn
    end

    return nil
end

---@param expression string
---@return table | false, string?
local function parseExpression(expression)
    local parts = {}
    for token in expression:gmatch('%S+') do parts[#parts + 1] = token:lower() end
    if #parts ~= 5 then
        return false, ('expression must have 5 fields, got %d'):format(#parts)
    end

    local units = { 'min', 'hour', 'day', 'month', 'wday' }
    local keys  = { '_min', '_hour', '_day', '_month', '_wday' }
    local parsed = { expression = expression }

    for i = 1, 5 do
        local field, err = parseField(parts[i], units[i])
        if err then
            return false, err
        end

        parsed[keys[i]] = field
    end

    return parsed, nil
end

---@param schedulerId number
---@param ts number
---@param slot table
local function scheduleInsert(schedulerId, ts, slot)
    if not schedule[ts] then
        schedule[ts] = {}
    end

    local bucket = schedule[ts]
    bucket[#bucket + 1] = slot
    index[schedulerId] = { ts = ts, pos = #bucket }
end

---@param schedulerId number
local function scheduleRemove(schedulerId)
    local idx = index[schedulerId]
    if not idx then return end

    local bucket = schedule[idx.ts]
    if not bucket then
        index[schedulerId] = nil
        return
    end

    local pos = idx.pos
    local last = #bucket

    if pos ~= last then
        local swapped = bucket[last]
        bucket[pos] = swapped
        index[swapped.schedulerId].pos = pos
    end

    bucket[last] = nil
    index[schedulerId] = nil

    if not bucket[1] then
        schedule[idx.ts] = nil
    end
end

local lastTick = os.time()

CreateThread(function()
    while true do
        local now = os.time()

        for ts = lastTick, now do
            local bucket = schedule[ts]

            if bucket then
                local snapshot = {}
                for i = 1, #bucket do snapshot[i] = bucket[i] end

                local delta = now - ts
                for i = 1, #snapshot do
                    local slot = snapshot[i]
                    local schedulerId = slot.schedulerId
                    local task = slot.task

                    if task.maxDelay == 0 or delta <= task.maxDelay then
                        TriggerEvent(('mnr:cronjob:%s'):format(slot.resource), schedulerId, ts)
                    else
                        TriggerEvent(('mnr:cronjob:%s:missed'):format(slot.resource), schedulerId, delta)
                    end

                    scheduleRemove(schedulerId)

                    local next = calcNextRun(task, now)
                    if next then
                        scheduleInsert(schedulerId, next, slot)
                    else
                        taskCount -= 1
                        TriggerEvent(('mnr:cronjob:%s:expired'):format(slot.resource), schedulerId)
                    end
                end
            end
        end

        lastTick = now + 1
        Wait(taskCount > 0 and 1000 or 30000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    local toRemove = {}
    for sid, idx in pairs(index) do
        local bucket = schedule[idx.ts]
        if bucket then
            local slot = bucket[idx.pos]
            if slot and slot.resource == resource then
                toRemove[#toRemove + 1] = sid
            end
        end
    end

    for i = 1, #toRemove do
        scheduleRemove(toRemove[i])
        taskCount -= 1
    end
end)

---@param resource string
---@param expression string
---@param maxDelay number
---@return number | false, string?
local function registerCronjob(resource, expression, maxDelay)
    if type(resource) ~= 'string' or resource == 'mnr_api' or GetResourceState(resource) ~= 'started' then
        return false, 'invalid resource'
    end
    if type(expression) ~= 'string' then
        return false, 'expression must be a string'
    end
    if type(maxDelay) ~= 'number' or maxDelay < 0 then
        return false, 'maxDelay must be a non-negative number'
    end

    local parsed, err = parseExpression(expression)
    if not parsed then
        return false, err
    end

    parsed.maxDelay = maxDelay

    local nextRun = calcNextRun(parsed, os.time())
    if not nextRun then
        return false, ('expression "%s" has no future occurrences'):format(expression)
    end

    currentSID += 1
    local schedulerId = currentSID

    local slot = { schedulerId = schedulerId, resource = resource, task = parsed }
    scheduleInsert(schedulerId, nextRun, slot)
    taskCount += 1

    return schedulerId, nil
end

---@param resource string
---@param schedulerId number
---@return boolean
local function unregisterCronjob(resource, schedulerId)
    if type(resource) ~= 'string' or resource == 'mnr_api' then
        return false
    end
    if type(schedulerId) ~= 'number' then
        return false
    end

    local idx = index[schedulerId]
    if not idx then
        return false
    end

    local bucket = schedule[idx.ts]
    if not bucket then
        return false
    end

    local slot = bucket[idx.pos]
    if not slot or slot.resource ~= resource then
        return false
    end

    scheduleRemove(schedulerId)
    taskCount -= 1

    return true
end

exports('RegisterCronjob', registerCronjob)
exports('UnregisterCronjob', unregisterCronjob)